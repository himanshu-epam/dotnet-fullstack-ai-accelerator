# Implementation Plan: [FEATURE NAME]

**Feature Branch**: [###-feature-name]
**Created**: [DATE]
**Author**: [AUTHOR]
**Status**: Draft | In Review | Approved
**Spec Reference**: [link to spec-template or file path]

---

## Summary

[One paragraph summarizing the primary requirement and the chosen technical approach.
State the key architectural decision and why it was made.]

---

## Technical Context

| Aspect                   | Choice                                                    |
| ------------------------ | --------------------------------------------------------- |
| **Language / Version**   | C# 12+ / .NET 9 (or .NET 8 LTS)                           |
| **API Style**            | Minimal APIs / Controllers (pick one)                     |
| **Architecture Pattern** | Vertical Slice / Clean Architecture (pick one)            |
| **Frontend Framework**   | Angular 18+ / React 18+ (pick one)                        |
| **Database**             | PostgreSQL / SQL Server (pick one)                        |
| **ORM**                  | Entity Framework Core 9 (or 8)                            |
| **Authentication**       | Azure Entra ID via Microsoft.Identity.Web                 |
| **API Documentation**    | Scalar + OpenAPI                                          |
| **Testing (Backend)**    | xUnit, NSubstitute, WebApplicationFactory, Testcontainers |
| **Testing (Frontend)**   | Jest or Vitest, Testing Library                           |
| **CI/CD**                | Azure DevOps Pipelines (YAML)                             |
| **Deployment Target**    | Docker on Azure AKS with KEDA                             |

---

## Constitution Compliance Check

> GATE: All items must pass before implementation begins.
> Reference: .specify/memory/constitution.md

| #   | Constitution Section     | Requirement                                                   | Compliant | Notes |
| --- | ------------------------ | ------------------------------------------------------------- | :-------: | ----- |
| 1   | Section 1 — Architecture | API follows REST, versioned, Scalar docs, health checks       |    [ ]    |       |
| 2   | Section 2 — Auth         | Entra ID, [Authorize] default, secrets in Key Vault           |    [ ]    |       |
| 3   | Section 3 — Frontend     | Strict TypeScript, standalone/functional components, MSAL     |    [ ]    |       |
| 4   | Section 4 — Database     | EF Core code-first, parameterized queries, pagination         |    [ ]    |       |
| 5   | Section 5 — Testing      | xUnit AAA pattern, 80% coverage, Testcontainers               |    [ ]    |       |
| 6   | Section 6 — DevOps       | YAML pipeline, multi-stage Docker, AKS manifests              |    [ ]    |       |
| 7   | Section 7 — Code Quality | Nullable types, sealed classes, records, conventional commits |    [ ]    |       |
| 8   | Section 8 — Security     | Input validation, rate limiting, explicit CORS, dep scanning  |    [ ]    |       |

---

## Project Structure

[Document the project/folder structure for this feature.
For a new project, show the full solution structure.
For an existing project, show only the new/modified areas.]

    src/
    ├── MyApp.Api/
    │   ├── Controllers/ (or Endpoints/)
    │   │   └── [Resource]Controller.cs
    │   ├── Models/
    │   │   ├── Requests/
    │   │   │   └── Create[Resource]Request.cs
    │   │   └── Responses/
    │   │       └── [Resource]Response.cs
    │   └── Validators/
    │       └── Create[Resource]RequestValidator.cs
    ├── MyApp.Application/
    │   ├── Interfaces/
    │   │   └── I[Resource]Service.cs
    │   └── Services/
    │       └── [Resource]Service.cs
    ├── MyApp.Domain/
    │   └── Entities/
    │       └── [Resource].cs
    ├── MyApp.Infrastructure/
    │   ├── Data/
    │   │   ├── AppDbContext.cs
    │   │   └── Configurations/
    │   │       └── [Resource]Configuration.cs
    │   └── Repositories/
    │       └── [Resource]Repository.cs
    └── tests/
        ├── MyApp.Tests.Unit/
        │   └── Services/
        │       └── [Resource]ServiceTests.cs
        └── MyApp.Tests.Integration/
            └── Api/
                └── [Resource]ApiTests.cs

---

## Data Model

### Entities

[Define each entity with its properties, types, and constraints]

**[Entity 1 Name]**

| Property | Type            | Constraints                         | Notes                          |
| -------- | --------------- | ----------------------------------- | ------------------------------ |
| Id       | Guid            | PK, auto-generated                  | gen_random_uuid() for Postgres |
| [Field1] | string          | Required, MaxLength(256)            |                                |
| [Field2] | string          | Required, MaxLength(100)            |                                |
| [Field3] | DateTimeOffset  | Required, default CURRENT_TIMESTAMP |                                |
| [Field4] | DateTimeOffset? | Nullable                            | Set on update                  |

**Relationships**:

- [Entity 1] has many [Entity 2] (one-to-many)
- [Entity 1] belongs to [Entity 3] (many-to-one)

**Indexes**:

- Unique index on [Field1]
- Composite index on [Field2, Field3] for query performance

### EF Core Migration Plan

| Order | Migration Name      | What It Does                                            |
| :---: | ------------------- | ------------------------------------------------------- |
|   1   | Add[Entity]Table    | Creates the [entity] table with all columns and indexes |
|   2   | Add[Entity]SeedData | Seeds initial reference data (if needed)                |

---

## API Design

### Endpoints

| Method | Route                   | Description          |      Request Body       | Response                          |    Auth     |
| ------ | ----------------------- | -------------------- | :---------------------: | --------------------------------- | :---------: |
| GET    | /api/v1/[resource]      | List with pagination |            —            | PagedResult of [Resource]Response |     Yes     |
| GET    | /api/v1/[resource]/{id} | Get by ID            |            —            | [Resource]Response                |     Yes     |
| POST   | /api/v1/[resource]      | Create new           | Create[Resource]Request | [Resource]Response (201)          |     Yes     |
| PUT    | /api/v1/[resource]/{id} | Update               | Update[Resource]Request | [Resource]Response                |     Yes     |
| DELETE | /api/v1/[resource]/{id} | Delete               |            —            | 204 No Content                    | Yes (Admin) |

### Request/Response DTOs

**Create[Resource]Request**

| Field    | Type   | Validation               |
| -------- | ------ | ------------------------ |
| [Field1] | string | Required, MaxLength(256) |
| [Field2] | string | Required, MaxLength(100) |

**[Resource]Response**

| Field     | Type            | Notes                 |
| --------- | --------------- | --------------------- |
| Id        | Guid            |                       |
| [Field1]  | string          |                       |
| [Field2]  | string          |                       |
| CreatedAt | DateTimeOffset  |                       |
| UpdatedAt | DateTimeOffset? | Null if never updated |

### Error Responses

| Status Code | When                                   | Response Type                             |
| :---------: | -------------------------------------- | ----------------------------------------- |
|     400     | Validation fails                       | ProblemDetails with errors                |
|     401     | No valid token                         | ProblemDetails                            |
|     403     | Valid token but insufficient role      | ProblemDetails                            |
|     404     | Resource not found                     | ProblemDetails                            |
|     409     | Duplicate resource (unique constraint) | ProblemDetails                            |
|     500     | Unexpected server error                | ProblemDetails (no details in production) |

---

## Frontend Design

[Include this section if the feature has UI work]

### Components to Create

| Component            | Type           | Description                                   |
| -------------------- | -------------- | --------------------------------------------- |
| [Resource]ListPage   | Page/Route     | Displays paginated list with search           |
| [Resource]DetailPage | Page/Route     | Displays single resource with edit capability |
| [Resource]Form       | Form           | Create/edit form with validation              |
| [Resource]Card       | Presentational | Displays a single resource summary            |

### State Management

| State                | Type         | Managed By                               |
| -------------------- | ------------ | ---------------------------------------- |
| [Resource] list      | Server state | React Query / Angular HttpClient         |
| Selected [resource]  | Server state | React Query / Angular HttpClient         |
| Form state           | Local state  | React Hook Form / Angular Reactive Forms |
| Loading/error states | Derived      | React Query status / Angular signals     |

### Routes

| Path                 | Component                    | Auth Required |
| -------------------- | ---------------------------- | :-----------: |
| /[resource]          | [Resource]ListPage           |      Yes      |
| /[resource]/:id      | [Resource]DetailPage         |      Yes      |
| /[resource]/new      | [Resource]Form (create mode) |      Yes      |
| /[resource]/:id/edit | [Resource]Form (edit mode)   |      Yes      |

---

## Authentication and Authorization Design

| Aspect             | Implementation                                                     |
| ------------------ | ------------------------------------------------------------------ |
| API Authentication | JWT Bearer via Microsoft.Identity.Web                              |
| API Authorization  | [Authorize] at controller level, policy-based for admin operations |
| Frontend Auth      | MSAL.js with Authorization Code + PKCE flow                        |
| Token Injection    | Angular HttpInterceptor / React axios interceptor                  |
| Roles Required     | User (read/create/update), Admin (delete)                          |
| Scalar OAuth2      | Configured with Entra ID ClientId and scopes                       |

---

## Testing Strategy

### Backend Tests

| Test Type         | What to Test                        | Framework                   | Count (Estimate) |
| ----------------- | ----------------------------------- | --------------------------- | :--------------: |
| Unit — Service    | Business logic, validation, mapping | xUnit + NSubstitute         |       [N]        |
| Unit — Validators | Input validation rules              | xUnit                       |       [N]        |
| Integration — API | Full HTTP request/response cycle    | WebApplicationFactory       |       [N]        |
| Integration — DB  | EF Core queries, migrations         | Testcontainers + PostgreSQL |       [N]        |

### Frontend Tests

| Test Type         | What to Test                   | Framework                     | Count (Estimate) |
| ----------------- | ------------------------------ | ----------------------------- | :--------------: |
| Unit — Components | Rendering, user interactions   | Jest/Vitest + Testing Library |       [N]        |
| Unit — Services   | API call logic, error handling | Jest/Vitest                   |       [N]        |
| Unit — Utils      | Helper functions, formatters   | Jest/Vitest                   |       [N]        |

---

## Deployment Plan

### Docker

- Multi-stage build using mcr.microsoft.com/dotnet/sdk:9.0-alpine (build) and aspnet:9.0-alpine (runtime)
- Non-root user in runtime image
- Expose port 8080

### Kubernetes (AKS)

| Resource          | Configuration                                          |
| ----------------- | ------------------------------------------------------ |
| Deployment        | 2 replicas minimum, rolling update strategy            |
| Service           | ClusterIP on port 80 targeting container port 8080     |
| Ingress           | Path-based routing with TLS                            |
| KEDA ScaledObject | CPU trigger at 70%, min 2, max 10 replicas             |
| Secrets           | Connection string and Entra ID config from K8s secrets |
| Health Probes     | Liveness at /health, Readiness at /ready               |

### Azure DevOps Pipeline

| Stage     | Steps                                                     |
| --------- | --------------------------------------------------------- |
| CI (PR)   | Restore → Build → Lint → Test → Security Scan             |
| CD (Main) | Build → Test → Docker Build → Push to ACR → Deploy to AKS |

---

## Implementation Phases

### Phase 0: Research and Spikes

[List any unknowns that need investigation before coding]

- [ ] Spike: [Unknown area that needs research]
- [ ] Spike: [Unknown area that needs research]

### Phase 1: Infrastructure and Data Layer

- EF Core entity, configuration, and migration
- DbContext registration and health checks
- Repository or direct DbContext usage

### Phase 2: API Layer

- DTOs (request/response records)
- Validation (FluentValidation or DataAnnotations)
- Service interface and implementation
- Controller/endpoint with auth and Scalar annotations
- Error handling middleware

### Phase 3: Frontend

- API service layer
- Components (list, detail, form, card)
- Routing with auth guards
- State management integration

### Phase 4: Testing

- Unit tests for services and validators
- Integration tests for API endpoints
- Frontend component tests
- Coverage verification

### Phase 5: Deployment

- Dockerfile
- Kubernetes manifests
- Pipeline configuration
- Smoke test in deployed environment

---

## Risks and Mitigations

| #   | Risk               | Impact          |   Likelihood    | Mitigation            |
| --- | ------------------ | --------------- | :-------------: | --------------------- |
| 1   | [Risk description] | High/Medium/Low | High/Medium/Low | [Mitigation strategy] |
| 2   | [Risk description] | High/Medium/Low | High/Medium/Low | [Mitigation strategy] |

---

## Open Decisions

| #   | Decision Needed | Options                  | Recommendation       | Status |
| --- | --------------- | ------------------------ | -------------------- | ------ |
| 1   | [Decision]      | A: [option], B: [option] | [Recommended option] | Open   |
| 2   | [Decision]      | A: [option], B: [option] | [Recommended option] | Open   |

---

_Plan created: [20-02-2026]_
_Last updated: [20-02-2026]_
