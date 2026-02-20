---
applyTo: " "
---

# Git Commit Message Instructions

## Format

Every commit message MUST follow this structure:

    <type>(<scope>): <short description>

    <optional body>

    <optional footer>

## Types

| Type     | When to Use                                             | Example                                             |
| -------- | ------------------------------------------------------- | --------------------------------------------------- |
| feat     | New feature or capability                               | feat(api): add user profile endpoint                |
| fix      | Bug fix                                                 | fix(auth): resolve token refresh loop               |
| docs     | Documentation only changes                              | docs(readme): update onboarding guide               |
| style    | Code formatting, no logic change                        | style(api): fix indentation in UserService          |
| refactor | Code change that neither fixes a bug nor adds a feature | refactor(api): extract validation to separate class |
| test     | Adding or updating tests                                | test(api): add unit tests for UserService           |
| chore    | Build, CI, tooling, dependencies                        | chore(deps): update EF Core to 9.0.1                |
| perf     | Performance improvement                                 | perf(db): add index on users email column           |
| ci       | CI/CD pipeline changes                                  | ci(pipeline): add code coverage publishing          |
| build    | Build system changes                                    | build(docker): optimize multi-stage Dockerfile      |
| revert   | Reverts a previous commit                               | revert: revert feat(api): add user profile endpoint |

## Scopes

Use lowercase scope names that identify the area of change:

| Scope    | Area                             |
| -------- | -------------------------------- |
| api      | Backend ASP.NET Core API         |
| ui       | Frontend Angular or React        |
| auth     | Authentication and authorization |
| db       | Database, migrations, EF Core    |
| docker   | Dockerfile and container changes |
| k8s      | Kubernetes manifests             |
| pipeline | Azure DevOps pipeline            |
| deps     | Dependency updates               |
| config   | Configuration changes            |
| test     | Test infrastructure              |
| docs     | Documentation                    |

Scope is optional but recommended. Use it when the change is clearly in one area.
Omit scope when the change spans multiple areas.

## Subject Line Rules

1. Use **imperative mood**: "add feature" NOT "added feature" or "adds feature"
2. Do NOT capitalize the first letter after the colon
3. Do NOT end with a period
4. Maximum **72 characters** for the entire subject line
5. Be specific: "add user profile endpoint" NOT "update code"

## Good Subject Line Examples

    feat(api): add paginated user list endpoint
    fix(auth): handle expired refresh token in MSAL interceptor
    test(api): add integration tests for user CRUD operations
    refactor(db): switch from AddDbContext to AddDbContextFactory
    chore(deps): update Microsoft.Identity.Web to 3.2.0
    ci(pipeline): add NuGet vulnerability scanning step
    docs(readme): add quick start guide for new teams
    perf(db): add composite index on users active and created_at
    build(docker): reduce API image size with Alpine base
    style(ui): apply Prettier formatting to all components

## Bad Subject Line Examples

    Updated the code                          ← too vague
    Fix bug                                   ← too vague, no scope
    feat(api): Add User Profile Endpoint.     ← capitalized, has period
    feat(api): added a new endpoint for user profiles that supports CRUD operations with pagination and filtering ← too long

## Body Rules

The body is optional but recommended for non-trivial changes.

1. Separate from subject with a **blank line**
2. Explain **WHY** the change was made, not WHAT (the diff shows what)
3. Wrap lines at **72 characters**
4. Use bullet points for multiple reasons

## Body Example

    feat(api): add user profile endpoint with CRUD operations

    User profiles are needed for the new dashboard feature.
    This endpoint allows the frontend to display and manage
    user information.

    - GET /api/v1/users — paginated list with search
    - GET /api/v1/users/{id} — single user by ID
    - POST /api/v1/users — create new user
    - PUT /api/v1/users/{id} — update existing user
    - DELETE /api/v1/users/{id} — admin only

## Footer Rules

The footer is optional. Use it for:

1. **Azure DevOps work item references**: AB#12345
2. **Breaking changes**: BREAKING CHANGE: description
3. **Co-authors**: Co-authored-by: Name <email>

## Footer Examples

### Work Item Reference

    feat(api): add user profile endpoint

    Implements the user profile management feature.

    AB#4567

### Breaking Change

    refactor(auth): change token audience format

    Changed the audience claim format from "api://client-id"
    to "https://api.example.com" to align with new Entra ID
    app registration.

    BREAKING CHANGE: API consumers must update their token
    request scope to use the new audience format.

    AB#4590

### Co-Author

    feat(ui): add user list component with pagination

    Co-authored-by: Alice Johnson <alice@example.com>
    AB#4567

## Multi-File Commit Examples

When a commit touches multiple areas, omit the scope or use a general scope:

    feat: add user management feature end to end

    Implements user CRUD from API to frontend:
    - API endpoint with Entra ID auth and Scalar docs
    - Angular components for list, detail, and form
    - EF Core entity with PostgreSQL configuration
    - xUnit unit and integration tests
    - Frontend component tests with Testing Library

    AB#4567

## Dependency Update Commits

    chore(deps): update Microsoft.Identity.Web to 3.2.0

    Includes fix for token cache serialization issue
    in multi-instance deployments.

    chore(deps): update Angular to 18.2.0

    Includes performance improvements for signal-based
    components and updated control flow internals.

    chore(deps): update multiple NuGet packages

    - Microsoft.EntityFrameworkCore 9.0.0 → 9.0.1
    - Npgsql.EntityFrameworkCore.PostgreSQL 9.0.0 → 9.0.1
    - xunit 2.9.0 → 2.9.2

## Commit Rules Summary

1. ALWAYS use conventional commit format: type(scope): description
2. ALWAYS use imperative mood in subject line
3. ALWAYS keep subject line under 72 characters
4. ALWAYS use lowercase for type and scope
5. ALWAYS use a blank line between subject and body
6. ALWAYS explain WHY in the body, not WHAT
7. ALWAYS reference Azure DevOps work items with AB#number when applicable
8. ALWAYS prefix breaking changes with BREAKING CHANGE: in the footer
9. NEVER capitalize the first letter after the colon
10. NEVER end the subject line with a period
11. NEVER write vague messages like "fix bug" or "update code"
12. NEVER include generated file changes without explanation
13. Use scope when change is in one area, omit when spanning multiple areas
14. Use bullet points in body for multiple related changes
15. One logical change per commit — do not mix unrelated changes
