---
applyTo: "**/*DbContext*.cs,**/*Repository*.cs,**/*Migration*,**/appsettings*.json,**/Data/**,**/Infrastructure/**,**/*Configuration*.cs"
---

# PostgreSQL Instructions

## Overview

PostgreSQL is the DEFAULT database for all new applications.
Use SQL Server only for legacy applications or when there is a specific business requirement.
Document the database choice in an Architecture Decision Record (ADR).

## Connection String Format

### appsettings.json (Placeholder Only)

    {
      "ConnectionStrings": {
        "DefaultConnection": "Host=localhost;Port=5432;Database=myapp;Username=postgres;Password=<FROM_USER_SECRETS>;SSL Mode=Prefer;Include Error Detail=true"
      }
    }

NEVER put real passwords in appsettings.json.
Use User Secrets for local development.
Use Azure Key Vault for deployed environments.

### Local Development — User Secrets

    dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=myapp;Username=postgres;Password=yourLocalPassword;SSL Mode=Prefer;Include Error Detail=true" --project src/MyApp.Api

### Production Connection String

    Host=myapp-db.postgres.database.azure.com;Port=5432;Database=myapp;Username=myapp_admin;Password=<FROM_KEYVAULT>;SSL Mode=Require;Trust Server Certificate=false

### Connection String Parameters

| Parameter                | Development | Production                     |
| ------------------------ | ----------- | ------------------------------ |
| Host                     | localhost   | \*.postgres.database.azure.com |
| Port                     | 5432        | 5432                           |
| SSL Mode                 | Prefer      | Require                        |
| Include Error Detail     | true        | false                          |
| Trust Server Certificate | true        | false                          |
| Pooling                  | true        | true                           |
| Minimum Pool Size        | 0           | 5                              |
| Maximum Pool Size        | 100         | 100                            |
| Connection Idle Lifetime | 300         | 300                            |

---

## DbContext Factory Registration for PostgreSQL

    builder.Services.AddDbContextFactory<AppDbContext>(options =>
        options.UseNpgsql(
            builder.Configuration.GetConnectionString("DefaultConnection"),
            npgsqlOptions =>
            {
                npgsqlOptions.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
                npgsqlOptions.EnableRetryOnFailure(
                    maxRetryCount: 3,
                    maxRetryDelay: TimeSpan.FromSeconds(10),
                    errorCodesToAdd: null);
                npgsqlOptions.CommandTimeout(30);
                npgsqlOptions.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery);
            }));

## Health Check Registration

    builder.Services.AddHealthChecks()
        .AddNpgSql(
            builder.Configuration.GetConnectionString("DefaultConnection")!,
            name: "postgresql",
            healthQuery: "SELECT 1;",
            tags: ["db", "ready"]);

---

## PostgreSQL Naming Conventions

PostgreSQL uses **snake_case** for all identifiers.
This differs from SQL Server which uses PascalCase.

| Element        | Convention             | Example                      |
| -------------- | ---------------------- | ---------------------------- |
| Table names    | snake_case, plural     | `users`, `user_profiles`     |
| Column names   | snake_case             | `created_at`, `display_name` |
| Primary keys   | `id`                   | `id`                         |
| Foreign keys   | `referenced_table_id`  | `owner_id`, `project_id`     |
| Indexes        | `ix_table_column`      | `ix_users_email`             |
| Unique indexes | `uq_table_column`      | `uq_users_email`             |
| Constraints    | `ck_table_description` | `ck_users_email_format`      |

## Automatic Snake Case Convention

Apply snake_case naming to all entities globally in DbContext:

    public sealed class AppDbContext(DbContextOptions<AppDbContext> options)
        : DbContext(options)
    {
        public DbSet<User> Users => Set<User>();
        public DbSet<Project> Projects => Set<Project>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Apply snake_case naming convention to all entities
            foreach (var entity in modelBuilder.Model.GetEntityTypes())
            {
                // Table name
                var tableName = entity.GetTableName();
                if (tableName is not null)
                {
                    entity.SetTableName(ToSnakeCase(tableName));
                }

                // Column names
                foreach (var property in entity.GetProperties())
                {
                    var columnName = property.GetColumnName(
                        StoreObjectIdentifier.Table(
                            entity.GetTableName()!, entity.GetSchema()));
                    property.SetColumnName(ToSnakeCase(columnName));
                }

                // Key names
                foreach (var key in entity.GetKeys())
                {
                    var keyName = key.GetName();
                    if (keyName is not null)
                    {
                        key.SetName(ToSnakeCase(keyName));
                    }
                }

                // Foreign key names
                foreach (var fk in entity.GetForeignKeys())
                {
                    var fkName = fk.GetConstraintName();
                    if (fkName is not null)
                    {
                        fk.SetConstraintName(ToSnakeCase(fkName));
                    }
                }

                // Index names
                foreach (var index in entity.GetIndexes())
                {
                    var indexName = index.GetDatabaseName();
                    if (indexName is not null)
                    {
                        index.SetDatabaseName(ToSnakeCase(indexName));
                    }
                }
            }

            modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
        }

        private static string ToSnakeCase(string input)
        {
            if (string.IsNullOrEmpty(input))
            {
                return input;
            }

            var builder = new StringBuilder();
            for (var i = 0; i < input.Length; i++)
            {
                var c = input[i];
                if (char.IsUpper(c))
                {
                    if (i > 0 && !char.IsUpper(input[i - 1]))
                    {
                        builder.Append('_');
                    }
                    else if (i > 0 && i < input.Length - 1 && char.IsUpper(input[i - 1]) && !char.IsUpper(input[i + 1]))
                    {
                        builder.Append('_');
                    }
                    builder.Append(char.ToLowerInvariant(c));
                }
                else
                {
                    builder.Append(c);
                }
            }
            return builder.ToString();
        }
    }

Alternative: Use the EFCore.NamingConventions NuGet package for automatic snake_case:

    // NuGet: EFCore.NamingConventions
    options.UseNpgsql(connectionString)
        .UseSnakeCaseNamingConvention();

---

## Entity Configuration Pattern for PostgreSQL

    public sealed class UserConfiguration : IEntityTypeConfiguration<User>
    {
        public void Configure(EntityTypeBuilder<User> builder)
        {
            // Table — explicit snake_case (if not using global convention)
            builder.ToTable("users");

            // Primary key with PostgreSQL UUID generation
            builder.HasKey(u => u.Id);
            builder.Property(u => u.Id)
                .HasColumnName("id")
                .HasDefaultValueSql("gen_random_uuid()");

            // String properties with explicit lengths
            builder.Property(u => u.Email)
                .HasColumnName("email")
                .HasMaxLength(256)
                .IsRequired();

            builder.Property(u => u.DisplayName)
                .HasColumnName("display_name")
                .HasMaxLength(100)
                .IsRequired();

            // Boolean with default
            builder.Property(u => u.IsActive)
                .HasColumnName("is_active")
                .HasDefaultValue(true);

            // Timestamps with PostgreSQL defaults
            builder.Property(u => u.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            builder.Property(u => u.UpdatedAt)
                .HasColumnName("updated_at");

            // Indexes
            builder.HasIndex(u => u.Email)
                .IsUnique()
                .HasDatabaseName("ix_users_email");

            builder.HasIndex(u => u.IsActive)
                .HasDatabaseName("ix_users_is_active")
                .HasFilter("is_active = true");

            // Relationships
            builder.HasMany(u => u.Projects)
                .WithOne(p => p.Owner)
                .HasForeignKey(p => p.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }

---

## PostgreSQL-Specific Data Types

### UUID (Primary Key)

    builder.Property(u => u.Id)
        .HasDefaultValueSql("gen_random_uuid()");

### Timestamps

    // Timestamp with time zone (preferred for all timestamps)
    builder.Property(u => u.CreatedAt)
        .HasColumnType("timestamptz")
        .HasDefaultValueSql("CURRENT_TIMESTAMP");

### JSON (use jsonb, NOT json)

    // Store complex objects as JSONB
    builder.Property(u => u.Metadata)
        .HasColumnType("jsonb")
        .HasColumnName("metadata");

    // In the entity
    public sealed class User : BaseEntity
    {
        // ... other properties
        public Dictionary<string, string>? Metadata { get; set; }
    }

### Text (use text instead of varchar for unlimited strings)

    // Use text when you do not need a max length constraint
    builder.Property(u => u.Description)
        .HasColumnType("text");

### Arrays (PostgreSQL-specific feature)

    // Store arrays natively
    builder.Property(u => u.Tags)
        .HasColumnType("text[]");

    // In the entity
    public sealed class Project : BaseEntity
    {
        // ... other properties
        public string[] Tags { get; set; } = [];
    }

    // Query arrays
    var projects = await dbContext.Projects
        .AsNoTracking()
        .Where(p => p.Tags.Contains("important"))
        .ToListAsync(cancellationToken);

### Enums (map to PostgreSQL enum or store as string)

    // Option 1: Store as string (simpler, recommended)
    builder.Property(u => u.Status)
        .HasConversion<string>()
        .HasMaxLength(50);

    // Option 2: Map to PostgreSQL enum (advanced)
    // Requires: NpgsqlConnection.GlobalTypeMapper.MapEnum<UserStatus>();
    builder.Property(u => u.Status)
        .HasColumnType("user_status");

### Money / Decimal

    builder.Property(p => p.Price)
        .HasColumnType("numeric(18,2)");

### Data Type Reference

| C# Type             | PostgreSQL Type | Notes                                 |
| ------------------- | --------------- | ------------------------------------- |
| Guid                | uuid            | Use gen_random_uuid() for default     |
| string              | text            | Unlimited length                      |
| string (max length) | varchar(n)      | When max length is needed             |
| int                 | integer         |                                       |
| long                | bigint          |                                       |
| decimal             | numeric(p,s)    | Specify precision and scale           |
| bool                | boolean         |                                       |
| DateTimeOffset      | timestamptz     | ALWAYS use timestamptz, not timestamp |
| DateTime            | timestamp       | Avoid — prefer DateTimeOffset         |
| byte[]              | bytea           | Binary data                           |
| string[]            | text[]          | Native array support                  |
| Dictionary          | jsonb           | JSON data                             |
| enum                | varchar(50)     | Store as string (recommended)         |

---

## Performance and Indexing

### Partial Indexes (PostgreSQL-specific)

Only index rows that match a condition — smaller index, faster queries:

    // Index only active users
    builder.HasIndex(u => u.Email)
        .HasDatabaseName("ix_users_email_active")
        .HasFilter("is_active = true");

    // Index only non-null values
    builder.HasIndex(u => u.UpdatedAt)
        .HasDatabaseName("ix_users_updated_at")
        .HasFilter("updated_at IS NOT NULL");

### Composite Indexes

    builder.HasIndex(u => new { u.IsActive, u.CreatedAt })
        .HasDatabaseName("ix_users_active_created");

### GIN Indexes for JSONB

    // For querying JSONB columns efficiently
    builder.HasIndex(u => u.Metadata)
        .HasDatabaseName("ix_users_metadata")
        .HasMethod("gin");

### Full-Text Search Index

    // For text search on multiple columns
    // Create via raw migration SQL
    migrationBuilder.Sql(@"
        CREATE INDEX ix_users_search
        ON users
        USING gin(to_tsvector('english', display_name || ' ' || email));
    ");

### Connection Pooling

PostgreSQL connection pooling is managed by Npgsql.
For high-traffic applications, consider using PgBouncer.

Configure connection pool in the connection string:

    Host=localhost;Port=5432;Database=myapp;Username=postgres;Password=secret;Pooling=true;Minimum Pool Size=5;Maximum Pool Size=100;Connection Idle Lifetime=300

---

## Docker Compose for Local Development

    # docker-compose.yml
    services:
      postgres:
        image: postgres:16-alpine
        container_name: myapp-postgres
        environment:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: localDevPassword123
          POSTGRES_DB: myapp
        ports:
          - "5432:5432"
        volumes:
          - postgres_data:/var/lib/postgresql/data
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U postgres"]
          interval: 10s
          timeout: 5s
          retries: 5

    volumes:
      postgres_data:

---

## Migration Tips for PostgreSQL

### Always Generate Idempotent Scripts for Production

    dotnet ef migrations script --idempotent --output migrations.sql --project src/MyApp.Infrastructure --startup-project src/MyApp.Api

### Custom Migration Operations

When EF Core migrations do not support a PostgreSQL feature, use raw SQL:

    public partial class AddFullTextSearch : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Create extension (if not already created)
            migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS pg_trgm;");

            // Create GIN index for text search
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS ix_users_search
                ON users
                USING gin(display_name gin_trgm_ops);
            ");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP INDEX IF EXISTS ix_users_search;");
        }
    }

### Enable PostgreSQL Extensions

Common extensions to enable:

    // In a migration
    migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";");   // UUID generation (legacy)
    migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";");     // gen_random_uuid()
    migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";");      // Trigram text search
    migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS \"citext\";");       // Case-insensitive text

---

## Rules Summary

### Connection Rules

1. ALWAYS use SSL Mode=Require in production connection strings
2. ALWAYS use User Secrets for local development connection strings
3. ALWAYS use Azure Key Vault for production connection strings
4. NEVER put real passwords in appsettings.json committed to source control
5. ALWAYS configure connection pooling (Minimum Pool Size=5 for production)
6. ALWAYS set Include Error Detail=true only in development

### Naming Rules

7. ALWAYS use snake_case for table names (users, not Users)
8. ALWAYS use snake_case for column names (created_at, not CreatedAt)
9. ALWAYS use snake*case for index names with ix* prefix (ix_users_email)
10. ALWAYS use snake_case for foreign key columns (owner_id, not OwnerId)
11. Use global snake_case convention or EFCore.NamingConventions package

### Data Type Rules

12. ALWAYS use `gen_random_uuid()` for UUID generation (not uuid_generate_v4)
13. ALWAYS use `CURRENT_TIMESTAMP` for default timestamps
14. ALWAYS use `timestamptz` for timestamp columns (not `timestamp`)
15. ALWAYS use `jsonb` for JSON data (not `json`)
16. ALWAYS use `text` instead of `varchar` when max length is not needed
17. ALWAYS store enums as strings with HasConversion unless performance requires native enum

### Index Rules

18. ALWAYS add indexes for columns used in WHERE clauses frequently
19. ALWAYS add unique indexes for natural keys (email, username)
20. Use partial indexes to reduce index size (HasFilter)
21. Use GIN indexes for JSONB and array columns
22. Use composite indexes for multi-column query patterns

### Performance Rules

23. ALWAYS use AddDbContextFactory (not AddDbContext)
24. ALWAYS use AsNoTracking for read-only queries
25. ALWAYS use pagination for list queries
26. ALWAYS use Select projection to fetch only needed columns
27. Use PgBouncer for high-traffic applications

### Migration Rules

28. ALWAYS generate idempotent scripts for production deployments
29. ALWAYS use IF NOT EXISTS for extension and index creation in raw SQL
30. ALWAYS include both Up and Down methods in custom migrations
31. NEVER modify an already-applied migration — create a new one
