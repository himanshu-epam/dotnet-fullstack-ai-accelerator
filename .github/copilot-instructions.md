# Global Copilot Instructions

> These instructions are automatically loaded for every GitHub Copilot interaction
> in this repository. They provide context about our tech stack, coding standards,
> and development practices.

## Governing Document

ALWAYS refer to `.specify/memory/constitution.md` for architectural principles and
coding standards. That file is the single source of truth for all development decisions.
When in doubt, the constitution wins.

---

## Tech Stack Context

You are working in a **full-stack .NET enterprise environment** with the following stack:

| Layer             | Technology                                                                        |
| ----------------- | --------------------------------------------------------------------------------- |
| Backend           | ASP.NET Core 8+, C# 12+, Entity Framework Core 8+                                 |
| Frontend          | Angular 18+ OR React 18+ (check package.json or angular.json to determine which)  |
| Database          | PostgreSQL (default) or SQL Server (check appsettings.json for connection string) |
| Authentication    | Azure Entra ID with OAuth 2.0 via Microsoft.Identity.Web                          |
| API Documentation | Scalar + OpenAPI (NOT Swagger UI)                                                 |
| Backend Testing   | xUnit, NSubstitute, WebApplicationFactory, Testcontainers                         |
| Frontend Testing  | Jest or Vitest with Testing Library                                               |
| CI/CD             | Azure DevOps Pipelines (YAML)                                                     |
| Deployment        | Docker containers on Azure Kubernetes Service (AKS) with KEDA scaling             |
| Cloud Provider    | Microsoft Azure (all services)                                                    |

---

## C# and .NET Code Generation Rules

1. ALWAYS use `async/await` for I/O operations — never use `.Result` or `.Wait()`
2. Use **dependency injection** via primary constructors — never instantiate services with `new`
3. Use **nullable reference types** — all new code must handle nullability correctly
4. Use `sealed` on classes not designed for inheritance
5. Use `record` types for DTOs and value objects
6. Generate **XML documentation comments** for all public APIs
7. Use **structured logging** with `ILogger<T>` — never use `Console.WriteLine`
8. Use the **Options pattern** (IOptions<T>) for configuration — never read IConfiguration directly in services
9. When creating API endpoints, ALWAYS include:
   - Proper HTTP status codes (200, 201, 204, 400, 401, 403, 404, 409, 500)
   - `[ProducesResponseType]` attributes for Scalar documentation
   - `[Authorize]` attribute (Entra ID bearer token)
   - Input validation (FluentValidation or DataAnnotations)
   - CancellationToken as the last parameter on all async methods
10. For Entity Framework Core:
    - Use `AsNoTracking()` for all read-only queries
    - Use `IEntityTypeConfiguration<T>` for entity configuration — never configure in OnModelCreating directly
    - Always include pagination for list queries
    - Use `AsSplitQuery()` for queries with multiple includes
11. Error handling:
    - Use **Result pattern** for expected business failures (not found, validation, conflicts)
    - Use **exceptions** only for truly unexpected errors
    - Return **ProblemDetails** (RFC 7807) for all error responses
12. Naming conventions:
    - PascalCase for public members, types, namespaces
    - \_camelCase for private fields
    - camelCase for local variables and parameters
    - IPascalCase for interfaces (prefix with I)
    - Async suffix for all async methods

---

## Angular Code Generation Rules

Only apply these when the project uses Angular (check for angular.json or @angular packages).

1. Use **standalone components** — never create NgModules
2. Use **signals** for reactive state management
3. Use `inject()` function instead of constructor injection
4. Use `ChangeDetectionStrategy.OnPush` on all components
5. Use `@for` and `@if` template syntax (Angular 17+ control flow)
6. Lazy-load feature routes
7. Use **strict TypeScript** — no `any` types
8. Use `HttpClient` with interceptors for auth token injection via MSAL Angular
9. Handle errors in services and display user-friendly messages
10. Use Angular CLI naming conventions for files:
    - Components: `user-list.component.ts`
    - Services: `user.service.ts`
    - Models: `user.model.ts`
    - Guards: `auth.guard.ts`

---

## React Code Generation Rules

Only apply these when the project uses React (check for react or next packages in package.json).

1. Use **functional components** only — no class components
2. Use **TypeScript** with strict mode — no `any` types
3. Use **React Query (TanStack Query)** for all server state management
4. Use **Zustand** for client-only state (if needed, avoid Redux for new projects)
5. Use **named exports** (not default exports)
6. Define **interfaces** for all component props
7. Colocate test files with components: `UserList.tsx` next to `UserList.test.tsx`
8. Use `@azure/msal-react` for authentication and token management
9. Use custom hooks to encapsulate reusable business logic
10. Use React Router v6+ with lazy loading for routes

---

## Testing Code Generation Rules

### Backend (xUnit)

1. Test naming: `MethodName_Should_ExpectedBehavior_When_Condition`
2. Use **Arrange-Act-Assert (AAA)** pattern with comment markers:

   // Arrange
   var service = new UserService(mockRepo);

   // Act
   var result = await service.GetByIdAsync(userId, CancellationToken.None);

   // Assert
   Assert.NotNull(result);

3. Use `[Fact]` for single-case tests, `[Theory]` with `[InlineData]` for parameterized tests
4. Use **NSubstitute** (Substitute.For<T>()) for mocking interfaces
5. ALWAYS include CancellationToken in async test calls
6. One assertion concept per test (multiple Assert calls for the same concept is OK)
7. Use `WebApplicationFactory<Program>` for integration tests
8. Use **Testcontainers** for database integration tests — never use a shared test database

### Frontend (Jest / Vitest)

1. Use `describe` and `it` blocks with meaningful descriptions
2. Use `beforeEach` to reset mocks and setup
3. Test user-visible behavior, NOT implementation details
4. Use Testing Library query priority: getByRole > getByLabelText > getByText > getByTestId
5. Use `userEvent` (not `fireEvent`) for user interactions
6. Use `waitFor` for async assertions
7. Mock all HTTP calls — NEVER hit real APIs in tests

---

## Testing Code Generation Rules

### Backend (xUnit)

1. Test naming: `MethodName_Should_ExpectedBehavior_When_Condition`
2. Use **Arrange-Act-Assert (AAA)** pattern with comment markers:

   // Arrange
   var service = new UserService(mockRepo);

   // Act
   var result = await service.GetByIdAsync(userId, CancellationToken.None);

   // Assert
   Assert.NotNull(result);

3. Use `[Fact]` for single-case tests, `[Theory]` with `[InlineData]` for parameterized tests
4. Use **NSubstitute** (Substitute.For<T>()) for mocking interfaces
5. ALWAYS include CancellationToken in async test calls
6. One assertion concept per test (multiple Assert calls for the same concept is OK)
7. Use `WebApplicationFactory<Program>` for integration tests
8. Use **Testcontainers** for database integration tests — never use a shared test database

### Frontend (Jest / Vitest)

1. Use `describe` and `it` blocks with meaningful descriptions
2. Use `beforeEach` to reset mocks and setup
3. Test user-visible behavior, NOT implementation details
4. Use Testing Library query priority: getByRole > getByLabelText > getByText > getByTestId
5. Use `userEvent` (not `fireEvent`) for user interactions
6. Use `waitFor` for async assertions
7. Mock all HTTP calls — NEVER hit real APIs in tests

---

## Security Rules

1. NEVER hardcode secrets, connection strings, or API keys in code or configuration files
2. NEVER use string interpolation in raw SQL queries
3. Always validate and sanitize user input on every endpoint
4. Use `[Authorize]` on controllers by default, `[AllowAnonymous]` explicitly and sparingly
5. Configure CORS with explicit origins — never use wildcards in production
6. Always use HTTPS redirection
7. Add rate limiting on public-facing APIs
8. Use Azure Key Vault for secrets in deployed environments
9. Use User Secrets (dotnet user-secrets) for local development secrets

---

## Git Rules

1. Use **conventional commits**: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`, `perf:`
2. Write clear, descriptive commit messages in imperative mood
3. Subject line: max 72 characters
4. Body: explain WHY, not WHAT (the diff shows what changed)
5. Reference Azure DevOps work items with AB#[number] when applicable

---

## File References

When generating code, check these files for patterns and context:

- `.specify/memory/constitution.md` — Architecture decisions and coding standards
- `.editorconfig` — Code formatting rules
- Existing controllers/endpoints — Follow established patterns in the project
- Existing test files — Follow established testing patterns in the project
- `appsettings.json` — Configuration structure and connection strings
