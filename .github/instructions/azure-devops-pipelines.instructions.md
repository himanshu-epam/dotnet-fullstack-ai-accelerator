---
applyTo: "**/*pipeline*,**/*azure-pipelines*,**/*.yml,**/*.yaml,**/.azuredevops/**"
---

# Azure DevOps Pipeline Instructions

## Overview

- ALWAYS use **YAML pipelines** — NEVER use the classic editor
- Separate **CI (build/test)** and **CD (deploy)** stages
- Use **templates** for reusable pipeline logic
- Use **variable groups** for environment-specific values
- Use **service connections** for Azure resource access
- NEVER store secrets in YAML files — use variable groups or Azure Key Vault

## Pipeline File Naming Convention

| File                         | Purpose                           |
| ---------------------------- | --------------------------------- |
| azure-pipelines.yml          | Main pipeline file (root of repo) |
| .azuredevops/ci-pipeline.yml | CI pipeline (build + test)        |
| .azuredevops/cd-pipeline.yml | CD pipeline (deploy)              |
| .azuredevops/templates/      | Reusable pipeline templates       |

---

## CI Pipeline — Build and Test

This pipeline triggers on PRs and main/develop branches.
It builds, lints, tests, and scans for vulnerabilities.

    # azure-pipelines.yml
    trigger:
      branches:
        include:
          - main
          - develop

    pr:
      branches:
        include:
          - main
          - develop

    pool:
      vmImage: 'ubuntu-latest'

    variables:
      buildConfiguration: 'Release'
      dotnetVersion: '9.0.x'
      nodeVersion: '20.x'
      DOTNET_CLI_TELEMETRY_OPTOUT: true
      DOTNET_NOLOGO: true

    stages:
      - stage: Build
        displayName: 'Build and Test'
        jobs:
          - job: BackendBuildAndTest
            displayName: 'Backend — Build, Test, Scan'
            steps:
              - task: UseDotNet@2
                displayName: 'Install .NET SDK'
                inputs:
                  packageType: 'sdk'
                  version: $(dotnetVersion)

              - task: Cache@2
                displayName: 'Cache NuGet packages'
                inputs:
                  key: 'nuget | "$(Agent.OS)" | **/packages.lock.json'
                  restoreKeys: |
                    nuget | "$(Agent.OS)"
                  path: $(NUGET_PACKAGES)

              - script: dotnet restore --locked-mode
                displayName: 'Restore NuGet packages'

              - script: dotnet build --configuration $(buildConfiguration) --no-restore
                displayName: 'Build solution'

              - script: dotnet test --configuration $(buildConfiguration) --no-build --collect:"XPlat Code Coverage" --results-directory $(Agent.TempDirectory)/TestResults --logger "trx;LogFileName=test-results.trx"
                displayName: 'Run unit and integration tests'

              - task: PublishTestResults@2
                displayName: 'Publish test results'
                condition: always()
                inputs:
                  testResultsFormat: 'VSTest'
                  testResultsFiles: '$(Agent.TempDirectory)/TestResults/**/*.trx'
                  mergeTestResults: true

              - task: PublishCodeCoverageResults@2
                displayName: 'Publish code coverage'
                condition: always()
                inputs:
                  summaryFileLocation: '$(Agent.TempDirectory)/TestResults/**/coverage.cobertura.xml'

              - script: dotnet list package --vulnerable --include-transitive 2>&1 | tee vulnerability-report.txt
                displayName: 'Check for vulnerable NuGet packages'

              - script: |
                  if grep -q "has the following vulnerable packages" vulnerability-report.txt; then
                    echo "##vso[task.logissue type=warning]Vulnerable NuGet packages detected"
                    cat vulnerability-report.txt
                  fi
                displayName: 'Report vulnerable packages'

              - script: dotnet publish src/MyApp.Api -c $(buildConfiguration) -o $(Build.ArtifactStagingDirectory)/api --no-restore
                displayName: 'Publish API'

              - task: PublishBuildArtifacts@1
                displayName: 'Publish API artifact'
                inputs:
                  PathtoPublish: '$(Build.ArtifactStagingDirectory)/api'
                  ArtifactName: 'api'

          - job: FrontendBuildAndTest
            displayName: 'Frontend — Build, Lint, Test'
            steps:
              - task: NodeTool@0
                displayName: 'Install Node.js'
                inputs:
                  versionSpec: $(nodeVersion)

              - task: Cache@2
                displayName: 'Cache npm packages'
                inputs:
                  key: 'npm | "$(Agent.OS)" | src/MyApp.Web/package-lock.json'
                  restoreKeys: |
                    npm | "$(Agent.OS)"
                  path: src/MyApp.Web/node_modules

              - script: |
                  cd src/MyApp.Web
                  npm ci
                displayName: 'Install npm packages'

              - script: |
                  cd src/MyApp.Web
                  npm run lint
                displayName: 'Run linter'

              - script: |
                  cd src/MyApp.Web
                  npm run test -- --ci --coverage --reporters=default --reporters=junit
                displayName: 'Run frontend tests'

              - task: PublishTestResults@2
                displayName: 'Publish frontend test results'
                condition: always()
                inputs:
                  testResultsFormat: 'JUnit'
                  testResultsFiles: 'src/MyApp.Web/junit.xml'
                  mergeTestResults: true
                  testRunTitle: 'Frontend Tests'

              - task: PublishCodeCoverageResults@2
                displayName: 'Publish frontend coverage'
                condition: always()
                inputs:
                  summaryFileLocation: 'src/MyApp.Web/coverage/cobertura-coverage.xml'

              - script: |
                  cd src/MyApp.Web
                  npm run build -- --configuration production
                displayName: 'Build frontend for production'

              - script: |
                  cd src/MyApp.Web
                  npm audit --audit-level=high
                displayName: 'Check for vulnerable npm packages'
                continueOnError: true

              - task: PublishBuildArtifacts@1
                displayName: 'Publish frontend artifact'
                inputs:
                  PathtoPublish: 'src/MyApp.Web/dist'
                  ArtifactName: 'frontend'

---

## CD Pipeline — Docker Build and Deploy to AKS

This pipeline triggers after a successful CI build on main branch.
It builds Docker images, pushes to Azure Container Registry, and deploys to AKS.

    # .azuredevops/cd-pipeline.yml
    trigger:
      branches:
        include:
          - main

    resources:
      pipelines:
        - pipeline: ci
          source: 'CI Pipeline'
          trigger:
            branches:
              include:
                - main

    pool:
      vmImage: 'ubuntu-latest'

    variables:
      - group: myapp-production    # Variable group with env-specific values
      - name: acrName
        value: 'myappregistry'
      - name: acrLoginServer
        value: 'myappregistry.azurecr.io'
      - name: imageTag
        value: '$(Build.BuildId)'

    stages:
      - stage: BuildImages
        displayName: 'Build and Push Docker Images'
        jobs:
          - job: BuildApiImage
            displayName: 'Build API Docker Image'
            steps:
              - task: Docker@2
                displayName: 'Build and push API image'
                inputs:
                  containerRegistry: 'AzureContainerRegistry'
                  repository: 'myapp-api'
                  command: 'buildAndPush'
                  Dockerfile: 'src/MyApp.Api/Dockerfile'
                  buildContext: '.'
                  tags: |
                    $(imageTag)
                    latest

          - job: BuildFrontendImage
            displayName: 'Build Frontend Docker Image'
            steps:
              - task: Docker@2
                displayName: 'Build and push frontend image'
                inputs:
                  containerRegistry: 'AzureContainerRegistry'
                  repository: 'myapp-frontend'
                  command: 'buildAndPush'
                  Dockerfile: 'src/MyApp.Web/Dockerfile'
                  buildContext: '.'
                  tags: |
                    $(imageTag)
                    latest

      - stage: DeployDev
        displayName: 'Deploy to Development'
        dependsOn: BuildImages
        condition: succeeded()
        jobs:
          - deployment: DeployToDev
            displayName: 'Deploy to Dev AKS'
            environment: 'myapp-dev'
            strategy:
              runOnce:
                deploy:
                  steps:
                    - template: templates/deploy-to-aks.yml
                      parameters:
                        environment: 'dev'
                        namespace: 'myapp-dev'
                        imageTag: $(imageTag)

      - stage: DeployStaging
        displayName: 'Deploy to Staging'
        dependsOn: DeployDev
        condition: succeeded()
        jobs:
          - deployment: DeployToStaging
            displayName: 'Deploy to Staging AKS'
            environment: 'myapp-staging'
            strategy:
              runOnce:
                deploy:
                  steps:
                    - template: templates/deploy-to-aks.yml
                      parameters:
                        environment: 'staging'
                        namespace: 'myapp-staging'
                        imageTag: $(imageTag)

      - stage: DeployProd
        displayName: 'Deploy to Production'
        dependsOn: DeployStaging
        condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
        jobs:
          - deployment: DeployToProd
            displayName: 'Deploy to Production AKS'
            environment: 'myapp-production'
            strategy:
              runOnce:
                deploy:
                  steps:
                    - template: templates/deploy-to-aks.yml
                      parameters:
                        environment: 'production'
                        namespace: 'myapp-production'
                        imageTag: $(imageTag)

---

## Reusable Deploy Template

    # .azuredevops/templates/deploy-to-aks.yml
    parameters:
      - name: environment
        type: string
      - name: namespace
        type: string
      - name: imageTag
        type: string

    steps:
      - task: KubernetesManifest@1
        displayName: 'Create namespace if not exists'
        inputs:
          action: 'deploy'
          kubernetesServiceConnection: 'AKS-${{ parameters.environment }}'
          namespace: '${{ parameters.namespace }}'
          manifests: |
            k8s/namespace.yml

      - task: KubernetesManifest@1
        displayName: 'Deploy secrets'
        inputs:
          action: 'deploy'
          kubernetesServiceConnection: 'AKS-${{ parameters.environment }}'
          namespace: '${{ parameters.namespace }}'
          manifests: |
            k8s/${{ parameters.environment }}/secrets.yml

      - task: KubernetesManifest@1
        displayName: 'Deploy application'
        inputs:
          action: 'deploy'
          kubernetesServiceConnection: 'AKS-${{ parameters.environment }}'
          namespace: '${{ parameters.namespace }}'
          manifests: |
            k8s/deployment.yml
            k8s/service.yml
            k8s/ingress.yml
          containers: |
            myappregistry.azurecr.io/myapp-api:${{ parameters.imageTag }}
            myappregistry.azurecr.io/myapp-frontend:${{ parameters.imageTag }}

      - task: Kubernetes@1
        displayName: 'Verify deployment rollout'
        inputs:
          connectionType: 'Kubernetes Service Connection'
          kubernetesServiceEndpoint: 'AKS-${{ parameters.environment }}'
          namespace: '${{ parameters.namespace }}'
          command: 'rollout'
          arguments: 'status deployment/myapp-api --timeout=300s'

      - script: |
          echo "Verifying health endpoints..."
          for i in {1..10}; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$(API_HOST)/health || echo "000")
            if [ "$STATUS" = "200" ]; then
              echo "Health check passed!"
              exit 0
            fi
            echo "Attempt $i: Status $STATUS, retrying in 10s..."
            sleep 10
          done
          echo "##vso[task.logissue type=error]Health check failed after 10 attempts"
          exit 1
        displayName: 'Verify health endpoint'

---

## Reusable Build Templates

### .NET Build and Test Template

    # .azuredevops/templates/dotnet-build-test.yml
    parameters:
      - name: buildConfiguration
        type: string
        default: 'Release'
      - name: dotnetVersion
        type: string
        default: '9.0.x'
      - name: publishProject
        type: string
        default: ''
      - name: artifactName
        type: string
        default: 'api'

    steps:
      - task: UseDotNet@2
        displayName: 'Install .NET SDK'
        inputs:
          packageType: 'sdk'
          version: ${{ parameters.dotnetVersion }}

      - script: dotnet restore --locked-mode
        displayName: 'Restore NuGet packages'

      - script: dotnet build --configuration ${{ parameters.buildConfiguration }} --no-restore
        displayName: 'Build solution'

      - script: dotnet test --configuration ${{ parameters.buildConfiguration }} --no-build --collect:"XPlat Code Coverage" --results-directory $(Agent.TempDirectory)/TestResults --logger "trx;LogFileName=test-results.trx"
        displayName: 'Run tests'

      - task: PublishTestResults@2
        displayName: 'Publish test results'
        condition: always()
        inputs:
          testResultsFormat: 'VSTest'
          testResultsFiles: '$(Agent.TempDirectory)/TestResults/**/*.trx'

      - task: PublishCodeCoverageResults@2
        displayName: 'Publish code coverage'
        condition: always()
        inputs:
          summaryFileLocation: '$(Agent.TempDirectory)/TestResults/**/coverage.cobertura.xml'

      - script: dotnet list package --vulnerable --include-transitive
        displayName: 'Security scan — NuGet vulnerabilities'

      - ${{ if ne(parameters.publishProject, '') }}:
        - script: dotnet publish ${{ parameters.publishProject }} -c ${{ parameters.buildConfiguration }} -o $(Build.ArtifactStagingDirectory)/${{ parameters.artifactName }} --no-restore
          displayName: 'Publish ${{ parameters.artifactName }}'

        - task: PublishBuildArtifacts@1
          displayName: 'Upload ${{ parameters.artifactName }} artifact'
          inputs:
            PathtoPublish: '$(Build.ArtifactStagingDirectory)/${{ parameters.artifactName }}'
            ArtifactName: '${{ parameters.artifactName }}'

### Frontend Build and Test Template

    # .azuredevops/templates/frontend-build-test.yml
    parameters:
      - name: nodeVersion
        type: string
        default: '20.x'
      - name: workingDirectory
        type: string
        default: 'src/MyApp.Web'
      - name: artifactName
        type: string
        default: 'frontend'

    steps:
      - task: NodeTool@0
        displayName: 'Install Node.js'
        inputs:
          versionSpec: ${{ parameters.nodeVersion }}

      - script: |
          cd ${{ parameters.workingDirectory }}
          npm ci
        displayName: 'Install npm packages'

      - script: |
          cd ${{ parameters.workingDirectory }}
          npm run lint
        displayName: 'Run linter'

      - script: |
          cd ${{ parameters.workingDirectory }}
          npm run test -- --ci --coverage
        displayName: 'Run tests'

      - script: |
          cd ${{ parameters.workingDirectory }}
          npm run build -- --configuration production
        displayName: 'Build for production'

      - script: |
          cd ${{ parameters.workingDirectory }}
          npm audit --audit-level=high
        displayName: 'Security scan — npm vulnerabilities'
        continueOnError: true

      - task: PublishBuildArtifacts@1
        displayName: 'Upload frontend artifact'
        inputs:
          PathtoPublish: '${{ parameters.workingDirectory }}/dist'
          ArtifactName: '${{ parameters.artifactName }}'

### Using Templates in Main Pipeline

    stages:
      - stage: Build
        jobs:
          - job: Backend
            displayName: 'Backend Build and Test'
            steps:
              - template: .azuredevops/templates/dotnet-build-test.yml
                parameters:
                  buildConfiguration: 'Release'
                  dotnetVersion: '9.0.x'
                  publishProject: 'src/MyApp.Api'
                  artifactName: 'api'

          - job: Frontend
            displayName: 'Frontend Build and Test'
            steps:
              - template: .azuredevops/templates/frontend-build-test.yml
                parameters:
                  nodeVersion: '20.x'
                  workingDirectory: 'src/MyApp.Web'
                  artifactName: 'frontend'

---

## Variable Groups

### Setting Up Variable Groups

Create variable groups in Azure DevOps for environment-specific configuration:

| Variable Group   | Purpose                        | Variables                                |
| ---------------- | ------------------------------ | ---------------------------------------- |
| myapp-common     | Shared across all environments | ACR name, ACR login server               |
| myapp-dev        | Development environment        | API host, DB connection, Entra ID config |
| myapp-staging    | Staging environment            | API host, DB connection, Entra ID config |
| myapp-production | Production environment         | API host, DB connection, Entra ID config |

### Common Variables

    AcrName: myappregistry
    AcrLoginServer: myappregistry.azurecr.io

### Environment-Specific Variables

    API_HOST: api-dev.example.com
    AZURE_AD_TENANT_ID: <linked from Key Vault>
    AZURE_AD_CLIENT_ID: <linked from Key Vault>
    DB_CONNECTION_STRING: <linked from Key Vault>

### Linking Key Vault Secrets to Variable Groups

1. Go to Pipelines > Library > Variable Group
2. Toggle "Link secrets from an Azure key vault as variables"
3. Select Key Vault and authorize
4. Add secrets: AzureAd--TenantId, AzureAd--ClientId, ConnectionStrings--Default

---

## Frontend Token Replacement

Replace placeholder tokens in frontend environment files during deployment:

    - task: replacetokens@6
      displayName: 'Replace tokens in frontend config'
      inputs:
        sources: '$(Pipeline.Workspace)/frontend/**/*.js'
        tokenPattern: 'doubleUnderscores'

This replaces **API_BASE_URL**, **AZURE_CLIENT_ID**, **AZURE_TENANT_ID**, etc.
with values from pipeline variables or variable groups.

Alternative using sed:

    - script: |
        cd $(Pipeline.Workspace)/frontend
        find . -name "*.js" -exec sed -i \
          -e "s|__API_BASE_URL__|$(API_BASE_URL)|g" \
          -e "s|__AZURE_CLIENT_ID__|$(AZURE_AD_CLIENT_ID)|g" \
          -e "s|__AZURE_TENANT_ID__|$(AZURE_AD_TENANT_ID)|g" \
          -e "s|__REDIRECT_URI__|$(REDIRECT_URI)|g" \
          -e "s|__API_SCOPE__|$(API_SCOPE)|g" \
          {} \;
      displayName: 'Replace frontend environment tokens'

---

## Database Migration in Pipeline

### Code-First — EF Core Migrations

    - task: UseDotNet@2
      displayName: 'Install .NET SDK'
      inputs:
        packageType: 'sdk'
        version: $(dotnetVersion)

    - script: dotnet tool install --global dotnet-ef
      displayName: 'Install EF Core tools'

    - script: dotnet ef database update --project src/MyApp.Infrastructure --startup-project src/MyApp.Api --connection "$(DB_CONNECTION_STRING)"
      displayName: 'Apply EF Core migrations'

### Database-First — SQL Script Execution

    - task: SqlAzureDacpacDeployment@1
      displayName: 'Execute SQL migration scripts'
      inputs:
        azureSubscription: 'AzureServiceConnection'
        authenticationType: 'servicePrincipal'
        ServerName: '$(DB_SERVER)'
        DatabaseName: '$(DB_NAME)'
        deployType: 'SqlTask'
        SqlFile: 'db/migrations/V$(Build.BuildId)__migration.sql'

### Generate Idempotent Script in CI (Safer for Production)

    - script: dotnet ef migrations script --idempotent --project src/MyApp.Infrastructure --startup-project src/MyApp.Api --output $(Build.ArtifactStagingDirectory)/migrations/migration.sql
      displayName: 'Generate idempotent migration script'

    - task: PublishBuildArtifacts@1
      displayName: 'Publish migration script'
      inputs:
        PathtoPublish: '$(Build.ArtifactStagingDirectory)/migrations'
        ArtifactName: 'migrations'

---

## Pipeline Folder Structure

    .azuredevops/
    ├── azure-pipelines.yml              ← Main CI pipeline (or root azure-pipelines.yml)
    ├── cd-pipeline.yml                  ← CD pipeline (deploy)
    └── templates/
        ├── dotnet-build-test.yml        ← Reusable .NET build+test template
        ├── frontend-build-test.yml      ← Reusable frontend build+test template
        ├── deploy-to-aks.yml            ← Reusable AKS deploy template
        ├── docker-build-push.yml        ← Reusable Docker build+push template
        └── run-migrations.yml           ← Reusable migration template

---

## Rules Summary

### Pipeline Structure Rules

1. ALWAYS use YAML pipelines — NEVER use classic editor
2. ALWAYS separate CI (build/test) and CD (deploy) stages
3. ALWAYS use reusable templates for repeated pipeline logic
4. ALWAYS use variable groups for environment-specific configuration
5. ALWAYS use service connections for Azure resource access
6. ALWAYS define pool at the top level (use ubuntu-latest)

### CI Rules

7. ALWAYS trigger CI on PR to main and develop
8. ALWAYS restore, build, test, and scan in CI
9. ALWAYS publish test results (PublishTestResults task)
10. ALWAYS publish code coverage (PublishCodeCoverageResults task)
11. ALWAYS scan for vulnerable NuGet packages (dotnet list package --vulnerable)
12. ALWAYS scan for vulnerable npm packages (npm audit)
13. ALWAYS cache NuGet and npm packages for faster builds
14. ALWAYS use --locked-mode for dotnet restore (ensures lock file matches)

### CD Rules

15. ALWAYS deploy through environments: dev → staging → production
16. ALWAYS use deployment jobs with environment approvals
17. ALWAYS use the KubernetesManifest task for AKS deployments
18. ALWAYS verify deployment rollout status after deploy
19. ALWAYS verify health endpoints after deploy
20. ALWAYS use Build.BuildId for image tags — NEVER use latest in production
21. ALWAYS run database migrations before application deployment

### Docker Rules

22. ALWAYS tag images with $(Build.BuildId) AND latest
23. ALWAYS push to Azure Container Registry via service connection
24. ALWAYS scan container images for vulnerabilities before deploy

### Security Rules

25. NEVER store secrets in YAML files
26. ALWAYS use variable groups linked to Azure Key Vault for secrets
27. ALWAYS use service connections with minimum required permissions
28. ALWAYS use --locked-mode for deterministic builds

### Template Rules

29. ALWAYS parameterize templates for reusability
30. ALWAYS provide sensible default values for template parameters
31. ALWAYS use type-safe parameter definitions (string, boolean, etc.)

### Frontend Deployment Rules

32. ALWAYS use token replacement for environment-specific frontend config
33. ALWAYS use placeholder tokens (**VARIABLE_NAME**) in production builds
34. ALWAYS replace tokens in the CD pipeline before deployment
