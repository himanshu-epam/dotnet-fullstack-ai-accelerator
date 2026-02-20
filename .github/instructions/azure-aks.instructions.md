---
applyTo: "**/Dockerfile*,**/.dockerignore,**/k8s/**,**/kubernetes/**,**/helm/**,**/kustomize/**,**/docker-compose*"
---

# Azure AKS Deployment Instructions

## Overview

- All deployable artifacts MUST be containerized with Docker
- All production deployments target Azure Kubernetes Service (AKS)
- Use KEDA for event-driven autoscaling
- Use multi-stage Docker builds to minimize image size
- Run containers as non-root user
- ALWAYS include health probes, resource limits, and security context

---

## Dockerfile Pattern — .NET API (Multi-Stage)

    # ── Build Stage ──
    FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS build
    WORKDIR /src

    # Copy csproj files and restore (layer caching)
    COPY ["src/MyApp.Api/MyApp.Api.csproj", "MyApp.Api/"]
    COPY ["src/MyApp.Application/MyApp.Application.csproj", "MyApp.Application/"]
    COPY ["src/MyApp.Domain/MyApp.Domain.csproj", "MyApp.Domain/"]
    COPY ["src/MyApp.Infrastructure/MyApp.Infrastructure.csproj", "MyApp.Infrastructure/"]
    RUN dotnet restore "MyApp.Api/MyApp.Api.csproj"

    # Copy everything and publish
    COPY src/ .
    RUN dotnet publish "MyApp.Api/MyApp.Api.csproj" \
        -c Release \
        -o /app/publish \
        /p:UseAppHost=false

    # ── Runtime Stage ──
    FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime
    WORKDIR /app

    # Security: run as non-root user
    RUN addgroup -S appgroup && adduser -S appuser -G appgroup
    USER appuser

    # Copy published output
    COPY --from=build /app/publish .

    # Expose port (ASP.NET Core default in containers)
    EXPOSE 8080

    # Health check
    HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
        CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

    ENTRYPOINT ["dotnet", "MyApp.Api.dll"]

---

## Dockerfile Pattern — Angular Frontend

    # ── Build Stage ──
    FROM node:20-alpine AS build
    WORKDIR /app

    # Copy package files and install (layer caching)
    COPY src/MyApp.Web/package*.json ./
    RUN npm ci

    # Copy source and build
    COPY src/MyApp.Web/ .
    RUN npm run build -- --configuration production

    # ── Runtime Stage ──
    FROM nginx:1.27-alpine AS runtime

    # Security: run as non-root
    RUN addgroup -S appgroup && adduser -S appuser -G appgroup

    # Copy custom nginx config
    COPY src/MyApp.Web/nginx.conf /etc/nginx/nginx.conf

    # Copy built assets
    COPY --from=build /app/dist/my-app/browser /usr/share/nginx/html

    # Set ownership
    RUN chown -R appuser:appgroup /usr/share/nginx/html && \
        chown -R appuser:appgroup /var/cache/nginx && \
        chown -R appuser:appgroup /var/log/nginx && \
        touch /var/run/nginx.pid && \
        chown -R appuser:appgroup /var/run/nginx.pid

    USER appuser

    EXPOSE 8080

    HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
        CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

    CMD ["nginx", "-g", "daemon off;"]

### Nginx Configuration for SPA

    # nginx.conf
    worker_processes auto;
    pid /var/run/nginx.pid;

    events {
        worker_connections 1024;
    }

    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        sendfile on;
        keepalive_timeout 65;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://login.microsoftonline.com https://*.azurewebsites.net;" always;

        # Gzip compression
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml;
        gzip_min_length 1000;

        server {
            listen 8080;
            server_name _;
            root /usr/share/nginx/html;
            index index.html;

            # SPA routing — fallback to index.html
            location / {
                try_files $uri $uri/ /index.html;
            }

            # Cache static assets
            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }

            # Do not cache index.html
            location = /index.html {
                expires -1;
                add_header Cache-Control "no-store, no-cache, must-revalidate";
            }

            # Health check endpoint
            location /health {
                access_log off;
                return 200 "healthy";
                add_header Content-Type text/plain;
            }
        }
    }

---

## Dockerfile Pattern — React Frontend

    # ── Build Stage ──
    FROM node:20-alpine AS build
    WORKDIR /app

    COPY src/MyApp.Web/package*.json ./
    RUN npm ci

    COPY src/MyApp.Web/ .
    RUN npm run build

    # ── Runtime Stage ──
    FROM nginx:1.27-alpine AS runtime

    RUN addgroup -S appgroup && adduser -S appuser -G appgroup

    COPY src/MyApp.Web/nginx.conf /etc/nginx/nginx.conf
    COPY --from=build /app/dist /usr/share/nginx/html

    RUN chown -R appuser:appgroup /usr/share/nginx/html && \
        chown -R appuser:appgroup /var/cache/nginx && \
        chown -R appuser:appgroup /var/log/nginx && \
        touch /var/run/nginx.pid && \
        chown -R appuser:appgroup /var/run/nginx.pid

    USER appuser
    EXPOSE 8080

    HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
        CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

    CMD ["nginx", "-g", "daemon off;"]

## The same nginx.conf from the Angular section works for React as well.

## .dockerignore

ALWAYS include a .dockerignore to speed up builds and reduce image size:

    # Git
    .git
    .gitignore

    # IDE
    .vs
    .vscode
    .idea
    *.swp
    *.swo

    # Build artifacts
    **/bin
    **/obj
    **/node_modules
    **/dist
    **/out
    **/.angular

    # Test artifacts
    **/TestResults
    **/coverage

    # Docker
    **/Dockerfile*
    **/.dockerignore
    docker-compose*

    # Documentation
    **/*.md
    LICENSE

    # CI/CD
    .azuredevops
    .github
    .specify
    ai-rules

    # Local dev
    **/.env
    **/.env.local
    **/appsettings.Development.json

---

## Kubernetes Deployment Manifest

    # k8s/deployment.yml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp-api
      labels:
        app: myapp-api
        version: "1.0"
    spec:
      replicas: 2
      revisionHistoryLimit: 5
      selector:
        matchLabels:
          app: myapp-api
      strategy:
        type: RollingUpdate
        rollingUpdate:
          maxSurge: 1
          maxUnavailable: 0
      template:
        metadata:
          labels:
            app: myapp-api
        spec:
          serviceAccountName: myapp-api-sa
          automountServiceAccountToken: false
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            runAsGroup: 1000
            fsGroup: 1000
          containers:
            - name: myapp-api
              image: myappregistry.azurecr.io/myapp-api:latest
              ports:
                - containerPort: 8080
                  protocol: TCP
              resources:
                requests:
                  memory: "256Mi"
                  cpu: "250m"
                limits:
                  memory: "512Mi"
                  cpu: "500m"
              securityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                capabilities:
                  drop:
                    - ALL
              livenessProbe:
                httpGet:
                  path: /health
                  port: 8080
                initialDelaySeconds: 15
                periodSeconds: 30
                timeoutSeconds: 5
                failureThreshold: 3
              readinessProbe:
                httpGet:
                  path: /ready
                  port: 8080
                initialDelaySeconds: 5
                periodSeconds: 10
                timeoutSeconds: 5
                failureThreshold: 3
              startupProbe:
                httpGet:
                  path: /health
                  port: 8080
                initialDelaySeconds: 5
                periodSeconds: 5
                failureThreshold: 30
              env:
                - name: ASPNETCORE_ENVIRONMENT
                  value: "Production"
                - name: ASPNETCORE_URLS
                  value: "http://+:8080"
                - name: ConnectionStrings__DefaultConnection
                  valueFrom:
                    secretKeyRef:
                      name: myapp-secrets
                      key: db-connection-string
                - name: AzureAd__TenantId
                  valueFrom:
                    secretKeyRef:
                      name: myapp-secrets
                      key: azure-ad-tenant-id
                - name: AzureAd__ClientId
                  valueFrom:
                    secretKeyRef:
                      name: myapp-secrets
                      key: azure-ad-client-id
              volumeMounts:
                - name: tmp
                  mountPath: /tmp
          volumes:
            - name: tmp
              emptyDir: {}

---

## Kubernetes Service

    # k8s/service.yml
    apiVersion: v1
    kind: Service
    metadata:
      name: myapp-api
      labels:
        app: myapp-api
    spec:
      type: ClusterIP
      selector:
        app: myapp-api
      ports:
        - name: http
          port: 80
          targetPort: 8080
          protocol: TCP

---

## Kubernetes Ingress

    # k8s/ingress.yml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: myapp-ingress
      annotations:
        kubernetes.io/ingress.class: "nginx"
        cert-manager.io/cluster-issuer: "letsencrypt-prod"
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/use-regex: "true"
        nginx.ingress.kubernetes.io/rate-limit: "100"
        nginx.ingress.kubernetes.io/rate-limit-window: "1m"
        nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    spec:
      tls:
        - hosts:
            - api.example.com
            - app.example.com
          secretName: myapp-tls
      rules:
        - host: api.example.com
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: myapp-api
                    port:
                      number: 80
        - host: app.example.com
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: myapp-frontend
                    port:
                      number: 80

---

## Namespace

    # k8s/namespace.yml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: myapp-production
      labels:
        app: myapp
        environment: production

---

## Kubernetes Secrets

NEVER store secret values in YAML files committed to source control.
Use one of these approaches:

### Option 1: External Secrets Operator (Recommended)

Pull secrets from Azure Key Vault automatically:

    # k8s/external-secret.yml
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: myapp-secrets
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: azure-key-vault
        kind: ClusterSecretStore
      target:
        name: myapp-secrets
        creationPolicy: Owner
      data:
        - secretKey: db-connection-string
          remoteRef:
            key: ConnectionStrings--DefaultConnection
        - secretKey: azure-ad-tenant-id
          remoteRef:
            key: AzureAd--TenantId
        - secretKey: azure-ad-client-id
          remoteRef:
            key: AzureAd--ClientId

### Option 2: Sealed Secrets

Encrypt secrets before committing:

    # Encrypt with kubeseal
    kubectl create secret generic myapp-secrets \
      --from-literal=db-connection-string="Host=..." \
      --from-literal=azure-ad-tenant-id="..." \
      --from-literal=azure-ad-client-id="..." \
      --dry-run=client -o yaml | kubeseal --format yaml > k8s/sealed-secret.yml

### Option 3: Pipeline-Created Secrets

Create secrets via pipeline (values from variable groups):

    kubectl create secret generic myapp-secrets \
      --from-literal=db-connection-string="$(DB_CONNECTION_STRING)" \
      --from-literal=azure-ad-tenant-id="$(AZURE_AD_TENANT_ID)" \
      --from-literal=azure-ad-client-id="$(AZURE_AD_CLIENT_ID)" \
      --namespace myapp-production \
      --dry-run=client -o yaml | kubectl apply -f -

---

## ConfigMap

    # k8s/configmap.yml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: myapp-config
    data:
      ASPNETCORE_ENVIRONMENT: "Production"
      ASPNETCORE_URLS: "http://+:8080"
      Logging__LogLevel__Default: "Warning"
      Logging__LogLevel__Microsoft: "Warning"
      Logging__LogLevel__MyApp: "Information"

---

## Network Policy

Restrict traffic to only what is needed:

    # k8s/network-policy.yml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: myapp-api-network-policy
    spec:
      podSelector:
        matchLabels:
          app: myapp-api
      policyTypes:
        - Ingress
        - Egress
      ingress:
        # Allow traffic from ingress controller
        - from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: ingress-nginx
          ports:
            - port: 8080
              protocol: TCP
      egress:
        # Allow DNS
        - to:
            - namespaceSelector: {}
          ports:
            - port: 53
              protocol: UDP
            - port: 53
              protocol: TCP
        # Allow traffic to database
        - to:
            - ipBlock:
                cidr: 10.0.0.0/8
          ports:
            - port: 5432
              protocol: TCP
        # Allow traffic to Azure Entra ID
        - to:
            - ipBlock:
                cidr: 0.0.0.0/0
          ports:
            - port: 443
              protocol: TCP

---

## KEDA ScaledObject — Autoscaling

    # k8s/keda-scaledobject.yml
    apiVersion: keda.sh/v1alpha1
    kind: ScaledObject
    metadata:
      name: myapp-api-scaler
    spec:
      scaleTargetRef:
        name: myapp-api
      pollingInterval: 15
      cooldownPeriod: 60
      minReplicaCount: 2
      maxReplicaCount: 10
      triggers:
        # Scale based on CPU usage
        - type: cpu
          metricType: Utilization
          metadata:
            value: "70"
        # Scale based on HTTP requests (if using KEDA HTTP add-on)
        - type: prometheus
          metadata:
            serverAddress: http://prometheus.monitoring:9090
            metricName: http_requests_total
            query: sum(rate(http_requests_total{app="myapp-api"}[2m]))
            threshold: "100"

---

## Pod Disruption Budget

Ensure minimum availability during node maintenance and deployments:

    # k8s/pdb.yml
    apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: myapp-api-pdb
    spec:
      minAvailable: 1
      selector:
        matchLabels:
          app: myapp-api

---

## Service Account

    # k8s/service-account.yml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: myapp-api-sa
      annotations:
        azure.workload.identity/client-id: "<MANAGED_IDENTITY_CLIENT_ID>"
    automountServiceAccountToken: false

---

## Kubernetes Manifest Folder Structure

    k8s/
    ├── namespace.yml
    ├── deployment.yml
    ├── service.yml
    ├── ingress.yml
    ├── configmap.yml
    ├── network-policy.yml
    ├── keda-scaledobject.yml
    ├── pdb.yml
    ├── service-account.yml
    ├── external-secret.yml          ← or sealed-secret.yml
    └── environments/
        ├── dev/
        │   ├── kustomization.yml
        │   └── patches/
        │       └── replicas.yml
        ├── staging/
        │   ├── kustomization.yml
        │   └── patches/
        │       └── replicas.yml
        └── production/
            ├── kustomization.yml
            └── patches/
                └── replicas.yml

---

## Docker Compose for Local Development

    # docker-compose.yml
    services:
      api:
        build:
          context: .
          dockerfile: src/MyApp.Api/Dockerfile
        ports:
          - "7001:8080"
        environment:
          - ASPNETCORE_ENVIRONMENT=Development
          - ConnectionStrings__DefaultConnection=Host=postgres;Port=5432;Database=myapp;Username=postgres;Password=localDevPassword123
          - AzureAd__TenantId=${AZURE_AD_TENANT_ID}
          - AzureAd__ClientId=${AZURE_AD_CLIENT_ID}
        depends_on:
          postgres:
            condition: service_healthy

      frontend:
        build:
          context: .
          dockerfile: src/MyApp.Web/Dockerfile
        ports:
          - "4200:8080"
        depends_on:
          - api

      postgres:
        image: postgres:16-alpine
        environment:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: localDevPassword123
          POSTGRES_DB: myapp
        ports:
          - "5432:5432"
        volumes:
          - postgres_data:/var/lib/postgresql/data
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U postgres"]
          interval: 10s
          timeout: 5s
          retries: 5

    volumes:
      postgres_data:

---

## Rules Summary

### Docker Rules

1. ALWAYS use multi-stage builds (sdk for build, runtime-only for final image)
2. ALWAYS use Alpine-based images to minimize size
3. ALWAYS run containers as non-root user (adduser/USER)
4. ALWAYS copy csproj files first and restore separately (layer caching)
5. ALWAYS include a .dockerignore file
6. ALWAYS include HEALTHCHECK instruction in Dockerfile
7. ALWAYS expose port 8080 (ASP.NET Core container default)
8. ALWAYS set /p:UseAppHost=false for .NET publish
9. NEVER include development configs or secrets in Docker images
10. NEVER use latest tag in production manifests — use Build.BuildId

### Kubernetes Deployment Rules

11. ALWAYS set resource requests AND limits on containers
12. ALWAYS include liveness, readiness, AND startup probes
13. ALWAYS use RollingUpdate strategy with maxSurge=1, maxUnavailable=0
14. ALWAYS set revisionHistoryLimit (default 5)
15. ALWAYS use securityContext: runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities
16. ALWAYS mount /tmp as emptyDir for apps that need a writable temp directory
17. ALWAYS set automountServiceAccountToken to false unless needed

### Service and Ingress Rules

18. ALWAYS use ClusterIP service type (not LoadBalancer or NodePort)
19. ALWAYS configure TLS on ingress with cert-manager
20. ALWAYS enable SSL redirect on ingress
21. ALWAYS set rate limiting on ingress
22. ALWAYS set proxy body size limit on ingress

### Secrets Rules

23. NEVER store secret values in YAML files committed to source control
24. Use External Secrets Operator with Azure Key Vault (recommended)
25. Or use Sealed Secrets for encrypted secrets in Git
26. Or create secrets via pipeline from variable groups
27. ALWAYS use environment variables or volume mounts for secrets — never bake into images

### Scaling Rules

28. ALWAYS set minReplicaCount to at least 2 for production
29. ALWAYS include a Pod Disruption Budget for production
30. Use KEDA for event-driven autoscaling (CPU, HTTP, queue-based)
31. Set cooldownPeriod to prevent thrashing (60s minimum)

### Network Rules

32. ALWAYS apply NetworkPolicy to restrict traffic
33. Allow ingress only from ingress controller namespace
34. Allow egress only to required destinations (database, Azure AD, DNS)

### Frontend Container Rules

35. ALWAYS use nginx:alpine as the runtime image for SPA frontends
36. ALWAYS configure nginx for SPA routing (try_files fallback to index.html)
37. ALWAYS add security headers in nginx config
38. ALWAYS enable gzip compression in nginx
39. ALWAYS cache static assets with long expiry (1 year)
40. NEVER cache index.html — set no-store, no-cache
