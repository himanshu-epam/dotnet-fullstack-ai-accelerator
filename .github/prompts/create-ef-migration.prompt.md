---
agent: agent
description: "Create an EF Core code-first migration with entity, configuration, and DbContext registration"
---

# Create EF Core Migration

You are helping the developer create a new Entity Framework Core code-first migration.
Follow the organization's constitution at `.specify/memory/constitution.md` — specifically
Section 4 (Database Standards) and Section 7 (Code Quality).

## Inputs

- **Entity Name**: ${input:entityName:The name of the entity (e.g., Product, UserProfile)}
- **Properties**: ${input:properties:Comma-separated list of properties with types (e.g., Name:string, Price:decimal, IsActive:bool, CreatedAt:DateTimeOffset)}
- **Database**: ${input:database:postgres|sqlserver}
- **Table Name Override**: ${input:tableName:Leave blank to use pluralized entity name}
- **Relationships**: ${input:relationships:Describe relationships if any (e.g., belongs to Category, has many OrderItems)}

## Step 1 — Create or Update the Entity

Create the entity class in the Domain or Entities folder.

### Rules:

- Use a record if the entity is simple; use a class for complex entities with behavior
- ALWAYS include these base properties:
  - Id as Guid (primary key)
  - CreatedAt as DateTimeOffset
  - UpdatedAt as DateTimeOffset?
- Mark the class as sealed unless inheritance is explicitly needed
- Use nullable reference types — mark optional properties with ?
- Add XML documentation comments on the class and all public properties
- If relationships are specified, add navigation properties with proper types
  - One-to-many: ICollection of T initialized as new List of T
  - Many-to-one: nullable foreign key Guid? plus navigation property

### Entity Example Pattern:

    namespace MyApp.Domain.Entities;

    /// <summary>
    /// Represents a [entity description].
    /// </summary>
    public sealed class EntityName
    {
        /// <summary>Unique identifier.</summary>
        public Guid Id { get; set; }

        /// <summary>[Property description].</summary>
        public required string Name { get; set; }

        /// <summary>When the record was created.</summary>
        public DateTimeOffset CreatedAt { get; set; }

        /// <summary>When the record was last updated.</summary>
        public DateTimeOffset? UpdatedAt { get; set; }
    }

## Step 2 — Create the Entity Configuration

Create an IEntityTypeConfiguration class in the Infrastructure/Data/Configurations folder.

### Rules:

- File name: {EntityName}Configuration.cs
- Configure table name explicitly (use snake_case for PostgreSQL, PascalCase for SQL Server)
- Configure primary key with HasKey
- Configure all string properties with HasMaxLength
- Configure required properties with IsRequired()
- Configure indexes for frequently queried columns
- Configure unique constraints where applicable
- Configure relationships with proper cascade behavior:
  - Use DeleteBehavior.Restrict by default (NOT Cascade) to prevent accidental data loss
- For PostgreSQL: use gen_random_uuid() as default for Guid PKs
- For SQL Server: use NEWSEQUENTIALID() as default for Guid PKs
- Configure CreatedAt with database-level default:
  - PostgreSQL: .HasDefaultValueSql("CURRENT_TIMESTAMP")
  - SQL Server: .HasDefaultValueSql("GETUTCDATE()")

### Configuration Example Pattern:

    using Microsoft.EntityFrameworkCore;
    using Microsoft.EntityFrameworkCore.Metadata.Builders;

    namespace MyApp.Infrastructure.Data.Configurations;

    internal sealed class EntityNameConfiguration : IEntityTypeConfiguration<EntityName>
    {
        public void Configure(EntityTypeBuilder<EntityName> builder)
        {
            builder.ToTable("entity_names"); // snake_case for PostgreSQL

            builder.HasKey(e => e.Id);

            builder.Property(e => e.Id)
                .HasDefaultValueSql("gen_random_uuid()"); // PostgreSQL
                // .HasDefaultValueSql("NEWSEQUENTIALID()"); // SQL Server

            builder.Property(e => e.Name)
                .IsRequired()
                .HasMaxLength(256);

            builder.Property(e => e.CreatedAt)
                .IsRequired()
                .HasDefaultValueSql("CURRENT_TIMESTAMP"); // PostgreSQL
                // .HasDefaultValueSql("GETUTCDATE()"); // SQL Server

            // Indexes
            builder.HasIndex(e => e.Name)
                .IsUnique();
        }
    }

## Step 3 — Register Entity in DbContext

Update the application's DbContext class.

### Rules:

- Add a DbSet property for the new entity
- Ensure OnModelCreating calls ApplyConfigurationsFromAssembly (if not already present)
- Do NOT put configuration logic directly in OnModelCreating — always use separate configuration classes

### DbContext Pattern:

    public DbSet<EntityName> EntityNames => Set<EntityName>();

Verify OnModelCreating includes:

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }

## Step 4 — Generate the Migration

Provide the developer with the exact CLI commands to generate and apply the migration.

### For PostgreSQL and SQL Server (dotnet CLI):

    # Generate migration
    dotnet ef migrations add Add{EntityName}Table \
      --project src/MyApp.Infrastructure \
      --startup-project src/MyApp.Api \
      --context AppDbContext

    # Review the generated migration file before applying!

    # Apply migration to local database
    dotnet ef database update \
      --project src/MyApp.Infrastructure \
      --startup-project src/MyApp.Api

### Package Manager Console (Visual Studio):

    Add-Migration Add{EntityName}Table -Project MyApp.Infrastructure -StartupProject MyApp.Api
    Update-Database -Project MyApp.Infrastructure -StartupProject MyApp.Api

## Step 5 — Verify the Migration

After generating the migration, verify:

1. **Migration file** was created in the Migrations folder
2. **Up method** creates the table with all columns, constraints, and indexes
3. **Down method** properly drops the table (rollback safety)
4. **Snapshot file** was updated automatically
5. **No data loss warnings** — review the migration output carefully

## Reminders

- NEVER modify a migration that has already been applied to any environment
- If the migration is wrong, create a NEW migration to fix it
- Always review the generated SQL before applying to shared environments
- Use dotnet ef migrations script to generate SQL scripts for DBA review
- Migrations MUST be committed to source control
- Test the migration with Testcontainers in integration tests
- Use AsNoTracking() for read-only queries against this new entity
- Add proper ProducesResponseType attributes when creating API endpoints for this entity
- Follow the organization's code review guidelines when submitting the migration for review
