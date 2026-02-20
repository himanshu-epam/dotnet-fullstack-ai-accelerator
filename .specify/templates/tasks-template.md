# Tasks: [FEATURE NAME]

**Feature Branch**: [###-feature-name]
**Created**: [DATE]
**Author**: [AUTHOR]
**Spec Reference**: [link to spec file]
**Plan Reference**: [link to plan file]

---

## Task Legend

| Symbol   | Meaning                                                        |
| -------- | -------------------------------------------------------------- |
| [P]      | Can run in **parallel** with other [P] tasks in the same phase |
| [S]      | **Sequential** — must complete before next task starts         |
| [US1]    | Belongs to **User Story 1** from the spec                      |
| [US2]    | Belongs to **User Story 2** from the spec                      |
| [SHARED] | Shared infrastructure — not tied to a specific user story      |
| P1       | Priority 1 — must have                                         |
| P2       | Priority 2 — should have                                       |
| P3       | Priority 3 — nice to have                                      |

---

## Phase 1: Project Setup and Shared Infrastructure [SHARED]

> Goal: Project compiles, runs, and has foundational plumbing in place.
> No business logic yet.

- [ ] T001 [S] [SHARED] Create solution and project structure per implementation plan
  - Create .sln file and all project references
  - Add Directory.Build.props with shared settings (nullable enable, implicit usings)
  - Add .editorconfig to solution root
  - Verify: `dotnet build` succeeds with zero warnings

- [ ] T002 [S] [SHARED] Add NuGet packages to all projects
  - Api: Microsoft.Identity.Web, Scalar.AspNetCore, FluentValidation.AspNetCore
  - Infrastructure: Npgsql.EntityFrameworkCore.PostgreSQL (or SqlServer equivalent)
  - Tests.Unit: xUnit, NSubstitute, FluentAssertions (if used)
  - Tests.Integration: Microsoft.AspNetCore.Mvc.Testing, Testcontainers.PostgreSql
  - Verify: `dotnet restore` succeeds

- [ ] T003 [P] [SHARED] Configure Program.cs with foundational middleware
  - Add authentication (Microsoft.Identity.Web)
  - Add authorization
  - Add OpenAPI with OAuth2 security scheme transformer
  - Add Scalar at /scalar/v1
  - Add CORS with explicit origins
  - Add rate limiting
  - Add health checks at /health and /ready
  - Verify: App starts and /health returns 200

- [ ] T004 [P] [SHARED] Configure DbContext and database connection
  - Create AppDbContext with OnModelCreating
  - Register in DI with connection string from configuration
  - Add health check for database connectivity
  - Verify: App starts without database errors (empty context is OK)

- [ ] T005 [P] [SHARED] Configure structured logging
  - Set up ILogger with appropriate log levels
  - Add request logging middleware
  - Verify: HTTP requests appear in console logs

- [ ] T006 [P] [SHARED] Create OAuth2 security scheme transformer for Scalar
  - Create OAuth2SecuritySchemeTransformer class
  - Wire up Entra ID authority, client ID, and scopes
  - Verify: /scalar/v1 shows OAuth2 authenticate button

**CHECKPOINT: Foundation ready. App compiles, starts, authenticates, and shows Scalar docs.**

---

## Phase 2: Data Layer [US1] (P1)

> Goal: Database schema exists with entities, configurations, and migrations.
> No API endpoints yet.

- [ ] T007 [S] [US1] Create domain entity classes
  - Create entity with all properties, types, and constraints from plan
  - Use appropriate C# types (Guid for ID, DateTimeOffset for timestamps)
  - Add navigation properties for relationships
  - Verify: Compiles without warnings

- [ ] T008 [S] [US1] Create EF Core entity configurations
  - Create IEntityTypeConfiguration class for each entity
  - Configure table name, column names, max lengths, indexes
  - Configure relationships and cascade behavior
  - Use PostgreSQL conventions (snake_case) or SQL Server conventions (PascalCase)
  - Verify: Compiles without warnings

- [ ] T009 [S] [US1] Add DbSet properties to AppDbContext
  - Add DbSet for each new entity
  - Apply configurations from assembly in OnModelCreating
  - Verify: Compiles without warnings

- [ ] T010 [S] [US1] Create and apply EF Core migration
  - Run: dotnet ef migrations add Add[Entity]Table
  - Review generated migration for correctness
  - Run: dotnet ef database update (local dev database)
  - Verify: Table exists in database with correct schema

**CHECKPOINT: Database schema is created and verified. Ready for business logic.**

---

## Phase 3: Business Logic Layer [US1] (P1)

> Goal: Service layer handles all business operations.
> No API endpoints yet — services are tested via unit tests.

- [ ] T011 [P] [US1] Create request and response DTOs
  - Create record types for all request DTOs (Create, Update)
  - Create record types for all response DTOs
  - Create PagedResult generic wrapper for list responses
  - Verify: Compiles without warnings

- [ ] T012 [P] [US1] Create input validators
  - Create FluentValidation (or DataAnnotations) validators for each request DTO
  - Include all validation rules from the plan (required, max length, format)
  - Verify: Compiles without warnings

- [ ] T013 [S] [US1] Create service interface
  - Define I[Resource]Service with all CRUD method signatures
  - Include CancellationToken parameter on all async methods
  - Return Task of appropriate response types
  - Verify: Compiles without warnings

- [ ] T014 [S] [US1] Implement service class
  - Implement all CRUD operations
  - Use AsNoTracking for read queries
  - Implement pagination for list operation
  - Map between entities and DTOs
  - Use ILogger for structured logging
  - Handle not-found scenarios (return null or Result pattern)
  - Register service in DI container
  - Verify: Compiles without warnings

- [ ] T015 [S] [US1] Write unit tests for service class
  - Test each public method with happy path
  - Test each public method with error/edge cases
  - Test validation logic
  - Use NSubstitute for mocking DbContext or repository
  - Follow AAA pattern with comment markers
  - Naming: MethodName_Should_ExpectedBehavior_When_Condition
  - Verify: All tests pass, coverage meets 80% target

**CHECKPOINT: Business logic complete and unit tested. Ready for API layer.**

---

## Phase 4: API Layer [US1] (P1)

> Goal: HTTP endpoints expose the business logic with proper auth, validation, and docs.

- [ ] T016 [S] [US1] Create controller or minimal API endpoints
  - Implement all endpoints from the plan (GET list, GET by ID, POST, PUT, DELETE)
  - Add [Authorize] at controller level
  - Add [Authorize(Policy = "...")] for admin-only operations
  - Add [AllowAnonymous] only where explicitly needed
  - Add [ProducesResponseType] for all possible status codes
  - Add [Tags] for Scalar grouping
  - Include CancellationToken in all async action methods
  - Verify: App starts and endpoints appear in Scalar

- [ ] T017 [P] [US1] Configure input validation in pipeline
  - Register FluentValidation validators in DI
  - Add validation filter or middleware to return 400 with ProblemDetails
  - Verify: Invalid input returns proper 400 response

- [ ] T018 [P] [US1] Add global exception handling middleware
  - Catch unhandled exceptions and return 500 ProblemDetails
  - Log full exception details server-side
  - Do NOT expose exception details in production responses
  - Verify: Unhandled exception returns clean 500 response

- [ ] T019 [S] [US1] Write integration tests for API endpoints
  - Use WebApplicationFactory to create test server
  - Use Testcontainers for real database in integration tests
  - Test each endpoint: happy path, validation error, not found, unauthorized
  - Verify proper status codes and response bodies
  - Verify: All integration tests pass

**CHECKPOINT: API complete, documented in Scalar, and integration tested.**

---

## Phase 5: Frontend [US1] (P1)

> Goal: UI components display data, handle user interactions, and authenticate via MSAL.

[Include this phase only if the feature has UI work. Remove if API-only.]

- [ ] T020 [S] [US1] Create API service layer
  - Create typed API client for all endpoints
  - Include auth token injection (MSAL interceptor)
  - Include error handling and error type mapping
  - Verify: Service compiles and types match API responses

- [ ] T021 [P] [US1] Create list page component
  - Display paginated list of resources
  - Include loading state and error state
  - Include search/filter if specified in the plan
  - Verify: Component renders with mock data

- [ ] T022 [P] [US1] Create detail page component
  - Display single resource details
  - Handle not-found state
  - Include edit and delete actions
  - Verify: Component renders with mock data

- [ ] T023 [P] [US1] Create form component (create and edit)
  - Build form with all fields from the plan
  - Add client-side validation matching API validation
  - Handle submit with loading state
  - Handle API errors and display to user
  - Verify: Form renders and validates correctly

- [ ] T024 [S] [US1] Configure routes and navigation
  - Add routes for list, detail, create, edit pages
  - Add auth guards (redirect to login if not authenticated)
  - Add navigation links to app menu
  - Verify: Navigation works end to end

- [ ] T025 [S] [US1] Write frontend component tests
  - Test each component renders correctly
  - Test user interactions (click, submit, navigate)
  - Test loading and error states
  - Mock all API calls
  - Verify: All frontend tests pass

**CHECKPOINT: UI complete and tested. Feature is fully functional end to end.**

---

## Phase 6: Additional User Stories (if applicable)

> Repeat Phases 2-5 pattern for each additional user story.

### User Story 2 — [Title] (P2)

- [ ] T026 [S] [US2] [Describe data layer task]
- [ ] T027 [S] [US2] [Describe business logic task]
- [ ] T028 [S] [US2] [Describe API layer task]
- [ ] T029 [S] [US2] [Describe frontend task]
- [ ] T030 [S] [US2] [Describe testing task]

**CHECKPOINT: User Story 2 independently functional and tested.**

---

## Phase 7: Deployment [SHARED]

> Goal: Feature is containerized, deployed to AKS, and verified in the deployed environment.

- [ ] T031 [P] [SHARED] Create or update Dockerfile
  - Multi-stage build (sdk for build, aspnet-alpine for runtime)
  - Non-root user in runtime image
  - Expose port 8080
  - Include .dockerignore
  - Verify: `docker build` succeeds and `docker run` starts the app

- [ ] T032 [P] [SHARED] Create or update Kubernetes manifests
  - Deployment with resource requests/limits
  - Service (ClusterIP)
  - Ingress with TLS (if new service)
  - KEDA ScaledObject (if autoscaling needed)
  - Kubernetes secrets for connection string and Entra ID config
  - Liveness probe at /health, readiness probe at /ready
  - Verify: Manifests pass `kubectl apply --dry-run=client`

- [ ] T033 [P] [SHARED] Create or update Azure DevOps pipeline
  - CI stage: restore, build, lint, test, security scan
  - CD stage: docker build, push to ACR, deploy to AKS
  - Verify: Pipeline runs successfully

- [ ] T034 [S] [SHARED] Deploy and run smoke tests
  - Deploy to development/staging environment
  - Verify health endpoints respond
  - Verify Scalar loads and OAuth2 works
  - Verify at least one CRUD operation end to end
  - Verify: Feature works in deployed environment

**CHECKPOINT: Feature deployed and verified in a real environment.**

---

## Phase 8: Polish and Cross-Cutting [SHARED]

> Goal: Final quality pass before marking the feature complete.

- [ ] T035 [P] [SHARED] Security review
  - Verify all endpoints require authentication
  - Verify admin-only operations check proper role/policy
  - Verify no secrets in source code
  - Verify input validation on all endpoints
  - Verify CORS is configured with explicit origins
  - Run `dotnet list package --vulnerable`

- [ ] T036 [P] [SHARED] Performance review
  - Verify AsNoTracking on read queries
  - Verify pagination on list endpoints
  - Verify proper database indexes exist
  - Verify no N+1 query problems

- [ ] T037 [P] [SHARED] Documentation
  - Update README if needed
  - Add/update API documentation in Scalar annotations
  - Document any environment variables or configuration needed
  - Document any manual steps for deployment

- [ ] T038 [S] [SHARED] Final test run and coverage check
  - Run all unit tests: `dotnet test`
  - Run all frontend tests: `npm run test`
  - Verify backend coverage is 80% or higher for business logic
  - Verify frontend coverage is 70% or higher for components with logic
  - Verify: All tests pass, coverage targets met

**CHECKPOINT: Feature is production-ready.**

---

## Summary

| Phase   |   Tasks   | Focus                                    | Depends On   |
| ------- | :-------: | ---------------------------------------- | ------------ |
| Phase 1 | T001–T006 | Project setup and infrastructure         | Nothing      |
| Phase 2 | T007–T010 | Data layer (entities, migrations)        | Phase 1      |
| Phase 3 | T011–T015 | Business logic and unit tests            | Phase 2      |
| Phase 4 | T016–T019 | API endpoints and integration tests      | Phase 3      |
| Phase 5 | T020–T025 | Frontend components and tests            | Phase 4      |
| Phase 6 | T026–T030 | Additional user stories                  | Phase 1      |
| Phase 7 | T031–T034 | Deployment (Docker, AKS, pipeline)       | Phase 4 or 5 |
| Phase 8 | T035–T038 | Security, performance, docs, final tests | Phase 7      |

**Total estimated tasks**: [N]
**Parallelizable tasks**: [N] (marked with [P])
**Critical path**: Phase 1 → 2 → 3 → 4 → 5 → 7 → 8

---

_Tasks created: [DATE]_
_Last updated: [DATE]_
