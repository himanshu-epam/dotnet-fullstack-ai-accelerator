---
agent: agent
description: "Scaffold a complete ASP.NET Core API endpoint following org standards"
---

# Create API Endpoint

Create a complete API endpoint for the resource described below.
Follow ALL standards from `.specify/memory/constitution.md` and `.github/instructions/dotnet-api.instructions.md`.

## Resource Details

- **Resource name**: ${input:resourceName:What is the resource name? (e.g., Product, Order, UserProfile)}
- **Operations**: ${input:operations:Which CRUD operations? (e.g., GetAll, GetById, Create, Update, Delete)}
- **Auth required**: ${input:authRequired:Is authentication required? (yes/no):yes}
- **Admin-only operations**: ${input:adminOps:Which operations require Admin role? (e.g., Delete, or none):Delete}

## Generate the Following Files

### 1. Entity Class

- Inherit from BaseEntity (Id, CreatedAt, UpdatedAt)
- Use `required` for mandatory properties
- Use `init` for properties set only during creation
- Use `sealed` modifier
- Include navigation properties if applicable
- Place in `Domain/Entities/` or `Entities/` folder

### 2. Entity Configuration (IEntityTypeConfiguration)

- Separate configuration class per entity
- Configure table name, column names, max lengths, indexes
- Check the project for PostgreSQL (snake_case) or SQL Server (PascalCase) conventions
- Configure UUID generation: gen_random_uuid() for PostgreSQL, NEWSEQUENTIALID() for SQL Server
- Configure timestamp defaults: CURRENT_TIMESTAMP for PostgreSQL, GETUTCDATE() for SQL Server
- Add unique index on natural key if applicable
- Use DeleteBehavior.Restrict for foreign keys
- Place in `Infrastructure/Data/Configurations/` folder

### 3. Request and Response DTOs

- Use `sealed record` types
- Add XML documentation with `/// <summary>` and `/// <example>`
- Add validation attributes: [Required], [StringLength], [EmailAddress] as needed
- Create: `Create{Resource}Request`, `Update{Resource}Request`, `{Resource}Response`
- Use the `PagedResult<T>` wrapper for list responses (create if not exists)
- Place in `Api/Models/Requests/` and `Api/Models/Responses/` folders

### 4. Service Interface and Implementation

- Interface: `I{Resource}Service` with all CRUD method signatures
- Implementation: `{Resource}Service` with `sealed` modifier
- Inject `IDbContextFactory<AppDbContext>` — NEVER inject DbContext directly
- Create DbContext per operation: `await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken)`
- Use `AsNoTracking()` for read-only queries
- Use `Select()` projection — never load entire entities for reads
- Include pagination for list operation (page, pageSize parameters)
- Include `CancellationToken` on all async methods
- Use `ILogger<T>` for structured logging
- Register service in DI container (show the registration line for Program.cs)
- Place interface in `Application/Interfaces/` and implementation in `Application/Services/`

### 5. Controller

- Use `sealed` modifier with primary constructor
- Add `[ApiController]`, `[Route("api/v1/[controller]")]`
- Add `[Authorize]` at controller level (if auth required)
- Add `[Produces("application/json")]`
- Add `[Tags("{Resource}s")]` for Scalar grouping
- Each action must have:
  - `/// <summary>` XML documentation
  - `/// <param>` for each parameter
  - `/// <response>` for each status code
  - `[ProducesResponseType]` for every possible status code (200, 201, 204, 400, 401, 403, 404, 409)
  - `CancellationToken cancellationToken = default` as last parameter
- GET list: return `PagedResult<T>` with `[FromQuery] int page = 1, [FromQuery] int pageSize = 20`
- GET by id: use `{id:guid}` route constraint, return 404 if not found
- POST: return `CreatedAtAction` with 201 status
- PUT: return 404 if not found, 200 with updated resource
- DELETE: add `[Authorize(Policy = "RequireAdmin")]` if admin-only, return 204 NoContent
- Place in `Api/Controllers/` folder

### 6. FluentValidation Validators (if FluentValidation is used in project)

- Create validator for each request DTO
- Include Required, MaxLength, Email format rules as applicable
- Place in `Api/Validators/` folder

### 7. DbContext Update

- Show the DbSet property to add to AppDbContext
- Show the ApplyConfigurationsFromAssembly call if not already present

### 8. DI Registration

- Show exact lines to add in Program.cs for:
  - Service registration
  - Validator registration (if using FluentValidation)

## Code Quality Requirements

- All code must compile without warnings
- All public members must have XML documentation
- No `any` or `var` where type is not obvious
- Use C# 12+ features: primary constructors, collection expressions, pattern matching
- Follow .editorconfig naming conventions
