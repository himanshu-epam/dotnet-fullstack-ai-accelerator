# Organization Constitution — Full-Stack .NET Development

> **This document defines the non-negotiable principles, standards, and architectural
> decisions that govern all full-stack .NET applications in our organization.**
>
> Every AI agent, every developer, every code review MUST adhere to these principles.
> Deviations require an Architecture Decision Record (ADR) with explicit justification.

---

## 1. Architecture Principles

### 1.1 API Design

- All APIs MUST be built with **ASP.NET Core 8+** using **Minimal APIs** or **Controllers**
- APIs MUST follow **RESTful** design principles with consistent resource naming
- All APIs MUST expose OpenAPI documentation via **Scalar** (NOT Swagger UI)
- APIs MUST include health checks at `/health` (liveness) and `/ready` (readiness)
- API versioning MUST be implemented using URL path versioning (`/api/v1/`)
- All API responses MUST use the standard ProblemDetails format for errors (RFC 7807)
- Example error response structure:

      {
        "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
        "title": "Bad Request",
        "status": 400,
        "detail": "Validation failed",
        "errors": { "field": ["error message"] }
      }

### 1.2 Project Structure

- **Prefer Vertical Slice Architecture** for feature-rich applications
- **Clean Architecture** is acceptable for complex domain logic
- Every solution MUST have clearly separated projects:
  - `*.Api` — API host, controllers/endpoints, middleware
  - `*.Application` — Business logic, use cases, interfaces
  - `*.Domain` — Entities, value objects, domain events (if warranted)
  - `*.Infrastructure` — Data access, external service integrations
  - `*.Tests.Unit` — Unit tests
  - `*.Tests.Integration` — Integration tests
- Keep it simple: Do NOT over-engineer. If the app is simple CRUD, a single project with folders is acceptable.

### 1.3 Patterns

- Use **MediatR** for CQRS only when complexity warrants it; simple CRUD should use services directly
- Use **Result pattern** (not exceptions) for expected business failures
- Use **exceptions** only for truly exceptional/unexpected scenarios
- Use **Options pattern** (IOptions) for configuration binding

---

## 2. Authentication and Authorization

### 2.1 Identity Provider

- ALL applications MUST use **Azure Entra ID** (formerly Azure AD) for authentication
- **NEVER** implement custom authentication (no custom login pages, no password storage)

### 2.2 Authentication Flows

- **SPAs (Angular/React)**: OAuth 2.0 Authorization Code flow with **PKCE**
- **Service-to-Service**: OAuth 2.0 Client Credentials flow
- **API Authentication**: JWT Bearer token validation via `Microsoft.Identity.Web`

### 2.3 Authorization

- Use **role-based** and/or **policy-based** authorization
- Controllers/endpoints MUST have `[Authorize]` by default; use `[AllowAnonymous]` explicitly
- Define roles in Entra ID App Registration, not in application code

### 2.4 Secrets Management

- **NEVER** store secrets, connection strings, or API keys in appsettings.json or source code
- Use **Azure Key Vault** for all secrets in deployed environments
- Use **User Secrets** (dotnet user-secrets) for local development
- Use **environment variables** in CI/CD pipelines

### 2.5 Scalar and OAuth2 Integration

- All APIs MUST expose Scalar API reference at `/scalar/v1`
- Scalar MUST be configured with OAuth2 authentication
- Use `IOpenApiDocumentTransformer` to add OAuth2 security schemes to the OpenAPI document
- Scalar configuration MUST include correct ClientId, Authority, and Scopes

---

## 3. Frontend Standards

### 3.1 General (Both Angular and React)

- **TypeScript** is MANDATORY — no `any` types in production code
- Strict mode MUST be enabled in tsconfig.json
- All components MUST be accessible (WCAG 2.1 AA minimum)
- Use **CSS Modules** or **component-scoped styles** — no global CSS leakage
- HTTP calls MUST go through a centralized API service layer
- Authentication MUST use **MSAL.js** (@azure/msal-browser, @azure/msal-angular, or @azure/msal-react)

### 3.2 Angular-Specific

- Use **standalone components** (no NgModules for new code)
- Use **signals** for reactive state management
- Use **Angular CLI** for all code generation
- Lazy-load feature routes
- State management: **NgRx SignalStore** or **Angular Signals** (NOT NgRx Store for new apps unless complexity warrants)
- HTTP: Use HttpClient with interceptors for auth token injection
- Use `inject()` function instead of constructor injection
- Use `ChangeDetectionStrategy.OnPush` for all components
- Use `@for` and `@if` template syntax (Angular 17+ control flow)

### 3.3 React-Specific

- Use **functional components** with hooks — no class components
- Use **React Query (TanStack Query)** for server state management
- Use **Zustand** for client state (if needed, avoid Redux for new projects)
- Use **React Router v6+** with lazy loading
- HTTP: Use a centralized fetch/axios wrapper with auth token injection
- Use **named exports** (not default exports)
- Colocate test files with components

---

## 4. Database Standards

### 4.1 Default Choice

- **PostgreSQL** is the DEFAULT database for all new applications
- **SQL Server** is supported for legacy applications or when there is a specific business requirement
- Document the database choice in an ADR

### 4.2 ORM and Data Access

- Use **Entity Framework Core** with **code-first migrations**
- Migrations MUST be versioned, idempotent, and included in source control
- Use `IDesignTimeDbContextFactory` for migration generation
- **NEVER** use raw SQL queries with string interpolation — always use parameterized queries or LINQ
- Configure entities using `IEntityTypeConfiguration` (separate configuration classes)

### 4.3 Connection Strings

- Local development: Use **User Secrets** or appsettings.Development.json
- Deployed environments: Use **Azure Key Vault** or **Azure App Configuration**
- Connection strings MUST use **SSL/TLS** in all non-local environments

### 4.4 Performance

- Use `AsNoTracking()` for read-only queries
- Implement **pagination** for all list endpoints (skip/take or cursor-based)
- Add database indexes for frequently queried columns
- Use `IQueryable` projections to avoid loading unnecessary data
- Use `AsSplitQuery()` for queries with multiple includes to avoid cartesian explosion
- Use `ExecuteUpdateAsync` / `ExecuteDeleteAsync` for bulk operations (EF Core 7+)

---

## 5. Testing Standards

### 5.1 Backend Testing (xUnit)

- Framework: **xUnit** (no MSTest or NUnit)
- Assertions: **xUnit built-in assertions** are preferred; **FluentAssertions** is acceptable
- Mocking: **NSubstitute** (preferred) or **Moq**
- **Minimum 80% code coverage** for business logic / application layer
- Test naming convention: `MethodName_Should_ExpectedBehavior_When_Condition`
- Use **Arrange-Act-Assert (AAA)** pattern in all tests with comment markers
- Integration tests MUST use `WebApplicationFactory` with **Testcontainers** for database
- **NO tests should depend on external services** — mock everything external

### 5.2 Frontend Testing (Jest / Vitest)

- Framework: **Jest** or **Vitest** (team choice, be consistent within project)
- Component testing: **Testing Library** (@testing-library/angular or @testing-library/react)
- Naming: `describe('ComponentName', () => { it('should do X when Y', ...) })`
- Mock HTTP calls — never hit real APIs in unit tests
- Minimum 70% coverage for components with business logic
- Use Testing Library query priority: getByRole > getByLabelText > getByText > getByTestId
- Use userEvent (not fireEvent) for user interactions

### 5.3 Test Organization

    tests/
    ├── Unit/
    │   ├── Application/         # Business logic tests
    │   └── Domain/              # Domain model tests
    ├── Integration/
    │   ├── Api/                 # API endpoint tests (WebApplicationFactory)
    │   └── Infrastructure/      # Database tests (Testcontainers)
    └── Architecture/            # ArchUnit-style tests (optional)

---

## 6. DevOps and Deployment

### 6.1 CI/CD Pipeline

- Use **Azure DevOps Pipelines** (YAML-based, NOT classic editor)
- Every PR triggers: build → lint → test → security scan
- Main/develop branch triggers: build → test → publish artifact → deploy

### 6.2 Containerization

- All deployable artifacts MUST be containerized with **Docker**
- Use **multi-stage builds** to minimize image size
- Base images: mcr.microsoft.com/dotnet/aspnet:9.0-alpine (or 8.0)
- Container images MUST be scanned for vulnerabilities before deployment
- Use .dockerignore to exclude unnecessary files
- Run containers as **non-root user**

### 6.3 Kubernetes / AKS

- All production deployments target **Azure Kubernetes Service (AKS)**
- Use **KEDA** for event-driven autoscaling where applicable
- Kubernetes manifests MUST include:
  - Resource requests and limits
  - Liveness and readiness probes
  - Pod disruption budgets for production
  - Network policies
- Use **Helm charts** or **Kustomize** for environment-specific configuration
- Tag images with build ID — never use `latest` in production manifests

### 6.4 Branching Strategy

- **Trunk-based development** is preferred for teams doing CI/CD
- **GitFlow** is acceptable for teams with longer release cycles
- Branch strategy MUST be documented in the repo README

---

## 7. Code Quality and Standards

### 7.1 C# Standards

- **Nullable reference types** MUST be enabled in all projects
- Use **primary constructors** for DI injection (C# 12+)
- Use **records** for DTOs and value objects
- Use **sealed** on classes that are not designed for inheritance
- Use **async/await** for ALL I/O operations — never block with .Result or .Wait()
- Use **structured logging** with ILogger — NEVER use Console.WriteLine
- Naming conventions:
  - PascalCase for public members, types, namespaces
  - \_camelCase for private fields
  - camelCase for local variables and parameters
  - IPascalCase for interfaces
  - Async suffix for async methods

### 7.2 Code Analysis

- `.editorconfig` MUST be present and enforced
- Enable .NET Analyzers at recommended level minimum
- Frontend: **ESLint** + **Prettier** with consistent configuration

### 7.3 Code Review

- All PRs require at least **1 reviewer**
- AI-generated code MUST be reviewed with the same rigor as human-written code
- Use **conventional commits** (feat:, fix:, chore:, docs:, test:, refactor:)

---

## 8. Security

### 8.1 OWASP Top 10

- All applications MUST mitigate the **OWASP Top 10** risks
- Input validation on EVERY user-facing endpoint
- Output encoding to prevent XSS
- Parameterized queries to prevent SQL injection (EF Core handles this by default)

### 8.2 API Security

- **Rate limiting** on all public-facing APIs (use Microsoft.AspNetCore.RateLimiting)
- **CORS** configured explicitly — NEVER use wildcard (\*) origins in production
- HTTPS enforced in all environments (use UseHttpsRedirection())
- Security headers: HSTS, X-Content-Type-Options, X-Frame-Options

### 8.3 Dependency Security

- **Dependency scanning** MUST be part of CI pipeline
- Use `dotnet list package --vulnerable` in CI
- Use `npm audit` or `yarn audit` for frontend dependencies
- Container image scanning with Azure Defender or Trivy

---

## Amendments

Changes to this constitution require:

1. An **Architecture Decision Record (ADR)** documenting the proposed change and rationale
2. Review and approval by **2 senior engineers or architects**
3. A PR to the accelerator repository with the updated constitution

---

_Last updated: 2026-02-20_
_Version: 1.0.0_
