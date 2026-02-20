---
applyTo: "**/*DbContext*.cs,**/*Repository*.cs,**/*Migration*,**/appsettings*.json,**/Data/**,**/Infrastructure/**,**/*Configuration*.cs"
---

# SQL Server Instructions

## Overview

SQL Server is supported for legacy applications or when there is a specific business requirement.
PostgreSQL is the default choice for new applications.
If choosing SQL Server, document the rationale in an Architecture Decision Record (ADR).

## Connection String Format

### appsettings.json (Placeholder Only)

    {
      "ConnectionStrings": {
        "DefaultConnection": "Server=localhost,1433;Database=MyApp;User Id=sa;Password=<FROM_USER_SECRETS>;TrustServerCertificate=True;Encrypt=True"
      }
    }

NEVER put real passwords in appsettings.json.
Use User Secrets for local development.
Use Azure Key Vault for deployed environments.

### Local Development — User Secrets

    dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost,1433;Database=MyApp;User Id=sa;Password=YourLocalPassword123!;TrustServerCertificate=True;Encrypt=True" --project src/MyApp.Api

### Production Connection String (Azure SQL)

    Server=tcp:myapp-sql.database.windows.net,1433;Database=MyApp;Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30

### Azure Managed Identity Connection (Recommended for Production)

    Server=tcp:myapp-sql.database.windows.net,1433;Database=MyApp;Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False

This uses Azure Managed Identity — no passwords stored anywhere.

### Connection String Parameters

| Parameter                | Development                 | Production (Azure SQL)       |
| ------------------------ | --------------------------- | ---------------------------- |
| Server                   | localhost,1433              | \*.database.windows.net,1433 |
| Encrypt                  | True                        | True                         |
| TrustServerCertificate   | True                        | False                        |
| Connection Timeout       | 30                          | 30                           |
| Authentication           | SQL Auth (User Id/Password) | Active Directory Default     |
| Min Pool Size            | 0                           | 5                            |
| Max Pool Size            | 100                         | 100                          |
| MultipleActiveResultSets | True                        | True                         |

---

## DbContext Factory Registration for SQL Server

    builder.Services.AddDbContextFactory<AppDbContext>(options =>
        options.UseSqlServer(
            builder.Configuration.GetConnectionString("DefaultConnection"),
            sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
                sqlOptions.EnableRetryOnFailure(
                    maxRetryCount: 3,
                    maxRetryDelay: TimeSpan.FromSeconds(10),
                    errorNumbersToAdd: null);
                sqlOptions.CommandTimeout(30);
                sqlOptions.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery);
            }));

## Health Check Registration

    builder.Services.AddHealthChecks()
        .AddSqlServer(
            builder.Configuration.GetConnectionString("DefaultConnection")!,
            name: "sqlserver",
            healthQuery: "SELECT 1;",
            tags: ["db", "ready"]);

---

## SQL Server Naming Conventions

SQL Server uses **PascalCase** for all identifiers.
This is the default EF Core behavior — no special convention needed.

| Element             | Convention             | Example                    |
| ------------------- | ---------------------- | -------------------------- |
| Table names         | PascalCase, plural     | `Users`, `UserProfiles`    |
| Column names        | PascalCase             | `CreatedAt`, `DisplayName` |
| Primary keys        | `Id`                   | `Id`                       |
| Foreign keys        | `ReferencedTableId`    | `OwnerId`, `ProjectId`     |
| Indexes             | `IX_Table_Column`      | `IX_Users_Email`           |
| Unique indexes      | `UQ_Table_Column`      | `UQ_Users_Email`           |
| Constraints         | `CK_Table_Description` | `CK_Users_EmailFormat`     |
| Default constraints | `DF_Table_Column`      | `DF_Users_IsActive`        |

Since PascalCase is the EF Core default, no global naming convention is needed.
Entity configurations only need to specify explicit names when they differ
from the EF Core conventions.

---

## Entity Configuration Pattern for SQL Server

    public sealed class UserConfiguration : IEntityTypeConfiguration<User>
    {
        public void Configure(EntityTypeBuilder<User> builder)
        {
            // Table
            builder.ToTable("Users");

            // Primary key with SQL Server sequential GUID
            builder.HasKey(u => u.Id);
            builder.Property(u => u.Id)
                .HasDefaultValueSql("NEWSEQUENTIALID()");

            // String properties with explicit lengths
            builder.Property(u => u.Email)
                .HasMaxLength(256)
                .IsRequired()
                .IsUnicode(true);

            builder.Property(u => u.DisplayName)
                .HasMaxLength(100)
                .IsRequired()
                .IsUnicode(true);

            // Boolean with default
            builder.Property(u => u.IsActive)
                .HasDefaultValue(true);

            // Timestamps with SQL Server defaults
            builder.Property(u => u.CreatedAt)
                .HasDefaultValueSql("GETUTCDATE()");

            builder.Property(u => u.UpdatedAt);

            // Indexes
            builder.HasIndex(u => u.Email)
                .IsUnique()
                .HasDatabaseName("IX_Users_Email");

            builder.HasIndex(u => u.IsActive)
                .HasDatabaseName("IX_Users_IsActive")
                .HasFilter("[IsActive] = 1");

            // Relationships
            builder.HasMany(u => u.Projects)
                .WithOne(p => p.Owner)
                .HasForeignKey(p => p.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }

### Why NEWSEQUENTIALID() Instead of NEWID()

| Aspect              | NEWID()            | NEWSEQUENTIALID()             |
| ------------------- | ------------------ | ----------------------------- |
| Value               | Random UUID        | Sequential UUID               |
| Clustered index     | Causes page splits | Sequential inserts, no splits |
| Insert performance  | Slower             | Faster                        |
| Index fragmentation | High               | Low                           |

## ALWAYS use NEWSEQUENTIALID() for GUID primary keys with clustered indexes in SQL Server.

## SQL Server-Specific Data Types

### GUID (Primary Key)

    builder.Property(u => u.Id)
        .HasDefaultValueSql("NEWSEQUENTIALID()");

### Timestamps

    // datetime2 is preferred over datetime
    builder.Property(u => u.CreatedAt)
        .HasColumnType("datetime2(7)")
        .HasDefaultValueSql("GETUTCDATE()");

ALWAYS use GETUTCDATE() (not GETDATE()) to store UTC timestamps.
ALWAYS use datetime2 (not datetime) for better precision and range.

### Strings (Unicode vs Non-Unicode)

    // nvarchar — Unicode (default for EF Core string properties)
    builder.Property(u => u.DisplayName)
        .HasMaxLength(100);
    // Generates: nvarchar(100)

    // varchar — Non-Unicode (use only when you know data is ASCII)
    builder.Property(u => u.CountryCode)
        .HasColumnType("varchar(3)")
        .HasMaxLength(3);

    // nvarchar(max) — Large Unicode text
    builder.Property(u => u.Description)
        .HasColumnType("nvarchar(max)");

### JSON (SQL Server 2022+ / Azure SQL)

    // Store as nvarchar(max) with JSON validation
    builder.Property(u => u.Metadata)
        .HasColumnType("nvarchar(max)");

    // EF Core 8+ JSON column mapping
    builder.OwnsOne(u => u.Address, addressBuilder =>
    {
        addressBuilder.ToJson();
    });

    // Entity with owned JSON type
    public sealed class User : BaseEntity
    {
        // ... other properties
        public Address? Address { get; set; }
    }

    public sealed class Address
    {
        public required string Street { get; set; }
        public required string City { get; set; }
        public required string PostalCode { get; set; }
        public required string Country { get; set; }
    }

### Money / Decimal

    builder.Property(p => p.Price)
        .HasColumnType("decimal(18,2)");

ALWAYS use decimal(18,2) for monetary values. NEVER use float or real.

### Computed Columns

    // Persisted computed column
    builder.Property(u => u.FullName)
        .HasComputedColumnSql("[FirstName] + ' ' + [LastName]", stored: true);

    // Non-persisted computed column
    builder.Property(u => u.DisplayLabel)
        .HasComputedColumnSql("[DisplayName] + ' (' + [Email] + ')'", stored: false);

### RowVersion for Concurrency

    // Automatic optimistic concurrency
    builder.Property(u => u.RowVersion)
        .IsRowVersion();

    // In the entity
    public sealed class User : BaseEntity
    {
        // ... other properties
        public byte[] RowVersion { get; set; } = null!;
    }

### Data Type Reference

| C# Type             | SQL Server Type           | Notes                              |
| ------------------- | ------------------------- | ---------------------------------- |
| Guid                | uniqueidentifier          | Use NEWSEQUENTIALID() for default  |
| string              | nvarchar(n)               | Unicode, specify max length        |
| string (unlimited)  | nvarchar(max)             | Large text                         |
| string (ASCII only) | varchar(n)                | Non-Unicode                        |
| int                 | int                       |                                    |
| long                | bigint                    |                                    |
| decimal             | decimal(p,s)              | Specify precision and scale        |
| bool                | bit                       |                                    |
| DateTimeOffset      | datetimeoffset(7)         | Preferred for timestamps           |
| DateTime            | datetime2(7)              | Use when DateTimeOffset not needed |
| byte[]              | varbinary(max)            | Binary data                        |
| byte[] (rowversion) | rowversion                | Optimistic concurrency             |
| JSON object         | nvarchar(max) or ToJson() | EF Core 8+ supports ToJson()       |
| enum                | nvarchar(50)              | Store as string (recommended)      |

---

## Performance and Indexing

### Filtered Indexes

Only index rows that match a condition — smaller index, faster queries:

    // Index only active users
    builder.HasIndex(u => u.Email)
        .HasDatabaseName("IX_Users_Email_Active")
        .HasFilter("[IsActive] = 1");

    // Index only non-null values
    builder.HasIndex(u => u.UpdatedAt)
        .HasDatabaseName("IX_Users_UpdatedAt")
        .HasFilter("[UpdatedAt] IS NOT NULL");

### Composite Indexes

    builder.HasIndex(u => new { u.IsActive, u.CreatedAt })
        .HasDatabaseName("IX_Users_Active_Created");

### Include Columns (Covering Index)

    // Include extra columns in the index to avoid key lookups
    // Must use raw migration SQL — EF Core does not support this natively
    migrationBuilder.Sql(@"
        CREATE NONCLUSTERED INDEX [IX_Users_Email_Include]
        ON [Users] ([Email])
        INCLUDE ([DisplayName], [CreatedAt]);
    ");

### Full-Text Search

    // Enable full-text search via migration
    migrationBuilder.Sql(@"
        CREATE FULLTEXT CATALOG [AppFullTextCatalog] AS DEFAULT;

        CREATE FULLTEXT INDEX ON [Users]
        ([DisplayName] LANGUAGE 1033, [Email] LANGUAGE 1033)
        KEY INDEX [PK_Users]
        ON [AppFullTextCatalog];
    ");

    // Query with full-text search
    var users = await dbContext.Users
        .AsNoTracking()
        .Where(u => EF.Functions.FreeText(u.DisplayName, searchTerm))
        .ToListAsync(cancellationToken);

### Query Hints

    // Use NOLOCK equivalent (read uncommitted) for reporting queries
    var users = await dbContext.Users
        .AsNoTracking()
        .TagWith("ReportingQuery")
        .ToListAsync(cancellationToken);

---

## Temporal Tables (SQL Server 2016+)

Automatically track data history:

### Enable via Migration

    migrationBuilder.Sql(@"
        ALTER TABLE [Users]
        ADD
            [ValidFrom] datetime2 GENERATED ALWAYS AS ROW START NOT NULL
                DEFAULT GETUTCDATE(),
            [ValidTo] datetime2 GENERATED ALWAYS AS ROW END NOT NULL
                DEFAULT CONVERT(datetime2, '9999-12-31 23:59:59.9999999'),
            PERIOD FOR SYSTEM_TIME ([ValidFrom], [ValidTo]);

        ALTER TABLE [Users]
        SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.UsersHistory));
    ");

### EF Core 8+ Temporal Table Support

    // In entity configuration
    builder.ToTable("Users", b => b.IsTemporal(t =>
    {
        t.HasPeriodStart("ValidFrom");
        t.HasPeriodEnd("ValidTo");
        t.UseHistoryTable("UsersHistory");
    }));

    // Query historical data
    var userHistory = await dbContext.Users
        .TemporalAll()
        .Where(u => u.Id == userId)
        .OrderBy(u => EF.Property<DateTime>(u, "ValidFrom"))
        .ToListAsync(cancellationToken);

    // Query data as of a specific point in time
    var userAtDate = await dbContext.Users
        .TemporalAsOf(specificDate)
        .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

---

## Database-First with SQL Server

### Scaffold from Existing SQL Server Database

    dotnet ef dbcontext scaffold "Server=localhost,1433;Database=MyApp;User Id=sa;Password=secret;TrustServerCertificate=True" Microsoft.EntityFrameworkCore.SqlServer --project src/MyApp.Infrastructure --startup-project src/MyApp.Api --context AppDbContext --context-dir Data --output-dir Entities --force --no-onconfiguring

### Scaffold Specific Tables

    dotnet ef dbcontext scaffold "connection-string" Microsoft.EntityFrameworkCore.SqlServer --tables Users --tables Projects --tables UserRoles --project src/MyApp.Infrastructure --startup-project src/MyApp.Api --force --no-onconfiguring

### Scaffold Specific Schema

    dotnet ef dbcontext scaffold "connection-string" Microsoft.EntityFrameworkCore.SqlServer --schema dbo --schema reporting --project src/MyApp.Infrastructure --startup-project src/MyApp.Api --force --no-onconfiguring

### SQL Server-Specific Scaffold Notes

1. PascalCase names map directly to PascalCase C# properties (no conversion needed)
2. uniqueidentifier columns map to Guid
3. datetime2 and datetimeoffset map to DateTime and DateTimeOffset
4. nvarchar(max) maps to string
5. bit maps to bool
6. decimal(p,s) maps to decimal
7. varbinary(max) maps to byte[]
8. Computed columns are scaffolded with HasComputedColumnSql
9. RowVersion columns are scaffolded with IsRowVersion

### Managing Schema Changes (Database-First)

Schema changes are managed via versioned SQL scripts:

    -- V001__add_user_status_column.sql
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'Status')
    BEGIN
        ALTER TABLE [Users]
        ADD [Status] nvarchar(50) NOT NULL DEFAULT 'Active';
    END
    GO

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_Status')
    BEGIN
        CREATE INDEX [IX_Users_Status]
        ON [Users] ([Status]);
    END
    GO

ALWAYS use IF NOT EXISTS / IF EXISTS guards for idempotent SQL scripts.

After applying the DB change, re-scaffold:

    dotnet ef dbcontext scaffold "connection-string" Microsoft.EntityFrameworkCore.SqlServer --force --no-onconfiguring --project src/MyApp.Infrastructure --startup-project src/MyApp.Api

### Re-Scaffold Script

    # scaffold-db.ps1
    param(
        [string]$ConnectionString = "Server=localhost,1433;Database=MyApp;User Id=sa;Password=secret;TrustServerCertificate=True"
    )

    Write-Host "Scaffolding SQL Server database..." -ForegroundColor Cyan

    dotnet ef dbcontext scaffold `
        $ConnectionString `
        Microsoft.EntityFrameworkCore.SqlServer `
        --project src/MyApp.Infrastructure `
        --startup-project src/MyApp.Api `
        --context AppDbContext `
        --context-dir Data `
        --output-dir Entities `
        --force `
        --no-onconfiguring

    Write-Host "Scaffold complete. Review generated files." -ForegroundColor Green
    Write-Host "Remember: Partial classes in Entities/Partials/ are preserved." -ForegroundColor Yellow

---

## Docker Compose for Local Development

    # docker-compose.yml
    services:
      sqlserver:
        image: mcr.microsoft.com/mssql/server:2022-latest
        container_name: myapp-sqlserver
        environment:
          ACCEPT_EULA: "Y"
          MSSQL_SA_PASSWORD: "YourStrong!Password123"
          MSSQL_PID: "Developer"
        ports:
          - "1433:1433"
        volumes:
          - sqlserver_data:/var/opt/mssql
        healthcheck:
          test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong!Password123" -Q "SELECT 1" -C -b
          interval: 10s
          timeout: 5s
          retries: 5

    volumes:
      sqlserver_data:

---

## Rules Summary

### Connection Rules

1. ALWAYS use Encrypt=True in all connection strings
2. ALWAYS use TrustServerCertificate=False in production
3. ALWAYS use Azure Managed Identity (Active Directory Default) for Azure SQL production
4. ALWAYS use User Secrets for local development connection strings
5. ALWAYS use Azure Key Vault for production connection strings
6. NEVER put real passwords in appsettings.json committed to source control
7. ALWAYS configure MultipleActiveResultSets=True if using lazy loading

### Naming Rules

8. ALWAYS use PascalCase for table names (Users, UserProfiles)
9. ALWAYS use PascalCase for column names (CreatedAt, DisplayName)
10. ALWAYS use IX\_ prefix for index names (IX_Users_Email)
11. ALWAYS use square brackets for identifiers in raw SQL ([Users], [Email])

### Data Type Rules

12. ALWAYS use NEWSEQUENTIALID() for GUID primary keys (not NEWID())
13. ALWAYS use GETUTCDATE() for default timestamps (not GETDATE())
14. ALWAYS use datetime2 instead of datetime (better precision and range)
15. ALWAYS use datetimeoffset when storing timezone-aware timestamps
16. ALWAYS use nvarchar for Unicode strings (not varchar unless ASCII-only)
17. ALWAYS use decimal(18,2) for monetary values (never float or real)
18. ALWAYS store enums as nvarchar with HasConversion unless performance requires int
19. Use ToJson() for JSON columns (EF Core 8+) or nvarchar(max) for older versions
20. Use RowVersion (byte[]) for optimistic concurrency

### Index Rules

21. ALWAYS add indexes for columns used in WHERE clauses frequently
22. ALWAYS add unique indexes for natural keys (email, username)
23. Use filtered indexes to reduce index size (HasFilter)
24. Use covering indexes (INCLUDE columns) to avoid key lookups
25. Use full-text indexes for text search scenarios

### Performance Rules

26. ALWAYS use AddDbContextFactory (not AddDbContext)
27. ALWAYS use AsNoTracking for read-only queries
28. ALWAYS use pagination for list queries
29. ALWAYS use Select projection to fetch only needed columns
30. Consider temporal tables for audit history requirements

### Code-First Migration Rules

31. ALWAYS generate idempotent scripts for production deployments
32. ALWAYS use IF NOT EXISTS guards in raw SQL migrations
33. ALWAYS include both Up and Down methods in custom migrations
34. NEVER modify an already-applied migration — create a new one

### Database-First Rules

35. ALWAYS use --no-onconfiguring flag when scaffolding
36. ALWAYS use --force flag to overwrite generated files
37. ALWAYS use partial classes for custom entity logic
38. NEVER modify generated entity files directly
39. NEVER use EF Core migrations with database-first
40. ALWAYS create a re-scaffold script for repeatable execution
