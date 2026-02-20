# AGENTS.md — Full-Stack .NET Organization

## Purpose

This file provides instructions for OpenAI Codex CLI and any generic AI agent
that does not have a dedicated rules file (.cursorrules, CLAUDE.md, .windsurfrules).

## Governing Document

Read `.specify/memory/constitution.md` for complete architectural standards.
Read `.github/instructions/` for technology-specific patterns.
These are the source of truth for all development decisions.

## Tech Stack

- Backend: ASP.NET Core 8/9+, C# 12+, Entity Framework Core
- Frontend: Angular 18+ or React 18+ (check package.json or angular.json)
- Database: PostgreSQL (default) or SQL Server (check appsettings.json)
- Auth: Azure Entra ID with OAuth 2.0 via Microsoft.Identity.Web
- API Docs: Scalar + OpenAPI (NOT Swagger UI)
- Backend Testing: xUnit, NSubstitute, WebApplicationFactory, Testcontainers
- Frontend Testing: Jest or Vitest with Testing Library
- CI/CD: Azure DevOps Pipelines (YAML)
- Deployment: Docker containers on Azure AKS with KEDA scaling
- Cloud: Microsoft Azure (all services)

## Instruction Files

This repository contains detailed instruction files for each technology.
Check these for specific patterns:

| File                                                        | Covers                                 |
| ----------------------------------------------------------- | -------------------------------------- |
| .github/instructions/dotnet-api.instructions.md             | ASP.NET Core API patterns              |
| .github/instructions/angular.instructions.md                | Angular component and service patterns |
| .github/instructions/react.instructions.md                  | React component and hook patterns      |
| .github/instructions/entity-framework.instructions.md       | EF Core with IDbContextFactory         |
| .github/instructions/azure-entra-id.instructions.md         | Auth for backend, Angular, and React   |
| .github/instructions/oauth2-swagger-scalar.instructions.md  | Scalar API docs with OAuth2            |
| .github/instructions/postgres.instructions.md               | PostgreSQL conventions and patterns    |
| .github/instructions/sqlserver.instructions.md              | SQL Server conventions and patterns    |
| .github/instructions/xunit-testing.instructions.md          | xUnit testing patterns                 |
| .github/instructions/jest-vitest-testing.instructions.md    | Frontend testing patterns              |
| .github/instructions/azure-devops-pipelines.instructions.md | CI/CD pipeline patterns                |
| .github/instructions/azure-aks.instructions.md              | Docker and Kubernetes patterns         |
| .github/instructions/git-commit.instructions.md             | Commit message format                  |

## Key Rules Summary

### C# and .NET

- async/await for all I/O — never .Result or .Wait()
- Dependency injection via primary constructors — never new up services
- sealed classes, record DTOs, nullable reference types enabled
- ILogger<T> for structured logging — never Console.WriteLine
- Options pattern (IOptions<T>) for configuration
- ProblemDetails (RFC 7807) for error responses

### API Endpoints

- [Authorize] at controller level, [AllowAnonymous] explicitly
- [ProducesResponseType] for all status codes
- CancellationToken on all async methods
- XML docs on all public actions
- Pagination for all list endpoints
- Input validation with FluentValidation or DataAnnotations

### Entity Framework Core

- AddDbContextFactory — NEVER AddDbContext
- Inject IDbContextFactory<T> — NEVER inject DbContext directly
- Create per-operation: await using var db = await factory.CreateDbContextAsync(ct)
- AsNoTracking() for reads, Select() projection, pagination always
- IEntityTypeConfiguration<T> for entity config
- Task.WhenAll with separate DbContext per parallel query

### Database

- PostgreSQL: snake_case, gen_random_uuid(), CURRENT_TIMESTAMP, jsonb, timestamptz
- SQL Server: PascalCase, NEWSEQUENTIALID(), GETUTCDATE(), datetime2, nvarchar

### Authentication

- Azure Entra ID only — never custom auth
- Backend: Microsoft.Identity.Web with JWT Bearer
- Angular: @azure/msal-angular with MsalInterceptor and MsalGuard
- React: @azure/msal-react with MsalProvider and useAuth hook
- SPAs: Authorization Code with PKCE — never Implicit flow

### Testing

- Backend: xUnit, NSubstitute, AAA pattern, 80% coverage
- Frontend: Testing Library, userEvent, waitFor, 70% coverage
- Integration: WebApplicationFactory + Testcontainers
- Mock all external services — never hit real APIs in tests

### Security

- NEVER hardcode secrets in code or config
- NEVER use string interpolation in raw SQL
- NEVER use wildcard CORS in production
- Validate all input, rate limit public APIs
- Key Vault for production, User Secrets for local dev

### Deployment

- Docker multi-stage builds, Alpine images, non-root user
- AKS with resource limits, health probes, network policies
- KEDA for autoscaling, PDB for availability
- Build.BuildId for image tags — never latest in production

### Git

- Conventional commits: feat:, fix:, chore:, docs:, test:, refactor:, perf:, ci:
- Imperative mood, max 72 char subject, explain WHY in body
- Reference work items: AB#12345

## When Making Changes

1. Check existing code patterns in the project first — match established style
2. Read .specify/memory/constitution.md for architecture decisions
3. Read .github/instructions/ for the relevant technology patterns
4. Create tests alongside implementation code
5. Use conventional commits
6. Ensure all public APIs have documentation and [ProducesResponseType]
7. Verify build and tests pass before committing
