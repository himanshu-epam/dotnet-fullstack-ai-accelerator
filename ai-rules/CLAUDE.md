# CLAUDE.md — Full-Stack .NET Organization

## Project Context

This is an enterprise full-stack .NET application repository.
Read `.specify/memory/constitution.md` for all architectural standards and coding rules.
That document is the single source of truth for every development decision.
When in doubt, the constitution wins.

## Tech Stack

| Layer            | Technology                                                    |
| ---------------- | ------------------------------------------------------------- |
| Backend          | ASP.NET Core 8/9+, C# 12+, Entity Framework Core              |
| Frontend         | Angular 18+ or React 18+ (check package.json or angular.json) |
| Database         | PostgreSQL (default) or SQL Server (check appsettings.json)   |
| Auth             | Azure Entra ID with OAuth 2.0 via Microsoft.Identity.Web      |
| API Docs         | Scalar + OpenAPI (NOT Swagger UI)                             |
| Backend Testing  | xUnit, NSubstitute, WebApplicationFactory, Testcontainers     |
| Frontend Testing | Jest or Vitest with Testing Library                           |
| CI/CD            | Azure DevOps Pipelines (YAML)                                 |
| Deployment       | Docker containers on Azure AKS with KEDA scaling              |
| Cloud            | Microsoft Azure (all services)                                |

## Before Writing Code

1. Check existing code in the project first — follow established patterns
2. Read `.specify/memory/constitution.md` for architecture decisions
3. Check `.github/instructions/` for technology-specific patterns
4. Check `.editorconfig` for formatting rules

## C# and .NET Standards

- async/await for ALL I/O — never .Result or .Wait()
- Dependency injection via primary constructors — never instantiate services with new
- Use sealed on all classes not designed for inheritance
- Use record types for DTOs and value objects
- Nullable reference types enabled — handle nullability correctly
- Structured logging with ILogger<T> — never Console.WriteLine
- Options pattern (IOptions<T>) for configuration
- ProblemDetails (RFC 7807) for all error responses

## API Endpoint Standards

- [Authorize] at controller level by default, [AllowAnonymous] explicitly
- [ProducesResponseType] for every possible HTTP status code
- CancellationToken as the last parameter on all async methods
- XML documentation comments on all public controller actions
- [Tags] attribute for Scalar grouping
- Route constraints on parameters: {id:guid}
- CreatedAtAction for POST (201), NoContent for DELETE (204)
- Input validation with FluentValidation or DataAnnotations
- Pagination for all list endpoints

## Entity Framework Core Standards

- Use AddDbContextFactory — NEVER use AddDbContext
- Inject IDbContextFactory<AppDbContext> — NEVER inject DbContext directly
- Create short-lived DbContext per operation:
  await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
- AsNoTracking() for all read-only queries
- Select() projection — never load entire entities when only a few fields are needed
- Pagination (Skip/Take) for all list queries
- IEntityTypeConfiguration<T> for entity config — never configure in OnModelCreating directly
- AsSplitQuery() for queries with multiple collection includes
- ExecuteUpdateAsync/ExecuteDeleteAsync for bulk operations
- Task.WhenAll with separate DbContext instances for parallel queries

## Database Conventions

### PostgreSQL (Default)

- snake_case for table names: users, user_profiles
- snake_case for column names: created_at, display_name
- gen_random_uuid() for UUID generation
- CURRENT_TIMESTAMP for default timestamps
- jsonb for JSON columns (not json)
- timestamptz for timestamps (not timestamp)

### SQL Server

- PascalCase for table names: Users, UserProfiles
- PascalCase for column names: CreatedAt, DisplayName
- NEWSEQUENTIALID() for GUID generation
- GETUTCDATE() for default timestamps
- datetime2 for timestamps (not datetime)
- nvarchar for Unicode strings

## Authentication Standards

### Backend

- Azure Entra ID via Microsoft.Identity.Web — never custom auth
- [Authorize] default, [AllowAnonymous] explicit
- Policy-based authorization: RequireAdmin, RequireUser, RequireReadAccess
- ClaimsPrincipalExtensions for extracting user info from JWT
- TestAuthHandler for integration test auth bypass

### Angular Frontend

- @azure/msal-angular with MsalInterceptor and MsalGuard
- Standalone components, signals, inject() function
- ChangeDetectionStrategy.OnPush, @for/@if template syntax

### React Frontend

- @azure/msal-react with MsalProvider and MsalAuthenticationTemplate
- useAuth custom hook for user info and role checking
- RequireRole component for role-based UI rendering
- apiClient with acquireTokenSilent interceptor

## Testing Standards

### Backend (xUnit)

- Test naming: MethodName_Should_ExpectedBehavior_When_Condition
- Arrange-Act-Assert (AAA) pattern with comment markers
- NSubstitute for mocking: Substitute.For<T>()
- [Fact] for single-case, [Theory] with [InlineData] for parameterized
- WebApplicationFactory + Testcontainers for integration tests
- Minimum 80% coverage for business logic

### Frontend (Jest/Vitest)

- Testing Library with query priority: getByRole > getByLabelText > getByText > getByTestId
- userEvent for interactions — never fireEvent
- waitFor for async assertions
- Mock all HTTP calls and auth — never hit real APIs
- Test all states: loading, success, error, empty
- Minimum 70% coverage for components with business logic

## Security — Non-Negotiable

- NEVER hardcode secrets, connection strings, or API keys in code or config files
- NEVER use string interpolation in raw SQL queries
- NEVER use wildcard (\*) CORS origins in production
- Always validate and sanitize user input on every endpoint
- Azure Key Vault for secrets in deployed environments
- User Secrets (dotnet user-secrets) for local development
- Rate limiting on all public-facing APIs
- HTTPS enforced in all environments

## DevOps and Deployment

- Azure DevOps YAML pipelines — never classic editor
- Docker multi-stage builds with Alpine base images
- Run containers as non-root user
- Azure AKS with KEDA for autoscaling
- Kubernetes: resource limits, health probes, network policies, PDB
- Image tags with Build.BuildId — never latest in production
- External Secrets Operator for Azure Key Vault integration

## Git Conventions

- Conventional commits: feat:, fix:, chore:, docs:, test:, refactor:, perf:, ci:
- Imperative mood: "add feature" not "added feature"
- Max 72 characters for subject line
- Explain WHY in body, not WHAT
- Reference Azure DevOps work items: AB#12345

## When Making Changes

1. Check existing code patterns in the project first
2. Follow the constitution at .specify/memory/constitution.md
3. Create tests alongside implementation code
4. Use conventional commits for all changes
5. Ensure all public APIs have XML documentation
6. Ensure all API endpoints have [ProducesResponseType] attributes
7. Run dotnet build and dotnet test before committing
8. Run npm run lint and npm run test before committing frontend changes
