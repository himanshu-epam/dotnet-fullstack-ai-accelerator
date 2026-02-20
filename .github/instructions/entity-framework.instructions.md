---
applyTo: "**/*DbContext*.cs,**/*Repository*.cs,**/Migrations/**,**/*Configuration*.cs,**/*Entity*.cs,**/Data/**,**/Infrastructure/**"
---

# Entity Framework Core Instructions

## DbContext Factory Pattern

We use IDbContextFactory to create DbContext instances on demand.
This enables parallel query execution, better connection management,
and works correctly with background services.

NEVER inject DbContext directly. ALWAYS inject IDbContextFactory and
create short-lived instances with `using` statements.

### Registration in Program.cs

PostgreSQL:

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
            }));

SQL Server:

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
            }));

### DbContext Class

    public sealed class AppDbContext(DbContextOptions<AppDbContext> options)
        : DbContext(options)
    {
        public DbSet<User> Users => Set<User>();
        public DbSet<Project> Projects => Set<Project>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
        }

        public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            foreach (var entry in ChangeTracker.Entries<BaseEntity>())
            {
                if (entry.State == EntityState.Modified)
                {
                    entry.Entity.UpdatedAt = DateTimeOffset.UtcNow;
                }
            }

            return await base.SaveChangesAsync(cancellationToken);
        }
    }

---

## Service Pattern Using IDbContextFactory

ALWAYS inject IDbContextFactory, NEVER inject DbContext directly.
Create short-lived DbContext instances using `await using` for each operation.

    public sealed class UserService(
        IDbContextFactory<AppDbContext> dbContextFactory,
        ILogger<UserService> logger) : IUserService
    {
        public async Task<PagedResult<UserResponse>> GetAllAsync(
            int page, int pageSize, CancellationToken cancellationToken = default)
        {
            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

            var totalCount = await dbContext.Users
                .AsNoTracking()
                .CountAsync(cancellationToken);

            var items = await dbContext.Users
                .AsNoTracking()
                .OrderBy(u => u.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(u => new UserResponse(
                    u.Id,
                    u.Email,
                    u.DisplayName,
                    u.CreatedAt,
                    u.UpdatedAt))
                .ToListAsync(cancellationToken);

            return new PagedResult<UserResponse>(items, totalCount, page, pageSize);
        }

        public async Task<UserResponse?> GetByIdAsync(
            Guid id, CancellationToken cancellationToken = default)
        {
            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

            return await dbContext.Users
                .AsNoTracking()
                .Where(u => u.Id == id)
                .Select(u => new UserResponse(
                    u.Id,
                    u.Email,
                    u.DisplayName,
                    u.CreatedAt,
                    u.UpdatedAt))
                .FirstOrDefaultAsync(cancellationToken);
        }

        public async Task<UserResponse> CreateAsync(
            CreateUserRequest request, CancellationToken cancellationToken = default)
        {
            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

            var user = new User
            {
                Email = request.Email,
                DisplayName = request.DisplayName
            };

            dbContext.Users.Add(user);
            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogInformation("Created user {UserId} with email {Email}", user.Id, user.Email);

            return new UserResponse(
                user.Id,
                user.Email,
                user.DisplayName,
                user.CreatedAt,
                user.UpdatedAt);
        }

        public async Task<UserResponse?> UpdateAsync(
            Guid id, UpdateUserRequest request, CancellationToken cancellationToken = default)
        {
            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

            var user = await dbContext.Users.FindAsync([id], cancellationToken);
            if (user is null)
            {
                return null;
            }

            user.DisplayName = request.DisplayName;
            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogInformation("Updated user {UserId}", user.Id);

            return new UserResponse(
                user.Id,
                user.Email,
                user.DisplayName,
                user.CreatedAt,
                user.UpdatedAt);
        }

        public async Task<bool> DeleteAsync(
            Guid id, CancellationToken cancellationToken = default)
        {
            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

            var deleted = await dbContext.Users
                .Where(u => u.Id == id)
                .ExecuteDeleteAsync(cancellationToken);

            return deleted > 0;
        }
    }

---

## Parallel Query Execution

One of the key advantages of IDbContextFactory is running queries in parallel.
Each parallel operation gets its own DbContext instance.

### Parallel Independent Queries

    public async Task<DashboardResponse> GetDashboardAsync(
        CancellationToken cancellationToken = default)
    {
        // Run all independent queries in parallel — each gets its own DbContext
        var userCountTask = GetUserCountAsync(cancellationToken);
        var projectCountTask = GetProjectCountAsync(cancellationToken);
        var recentUsersTask = GetRecentUsersAsync(5, cancellationToken);
        var activeProjectsTask = GetActiveProjectsAsync(5, cancellationToken);

        await Task.WhenAll(userCountTask, projectCountTask, recentUsersTask, activeProjectsTask);

        return new DashboardResponse(
            UserCount: await userCountTask,
            ProjectCount: await projectCountTask,
            RecentUsers: await recentUsersTask,
            ActiveProjects: await activeProjectsTask);
    }

    private async Task<int> GetUserCountAsync(CancellationToken cancellationToken)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
        return await dbContext.Users.AsNoTracking().CountAsync(cancellationToken);
    }

    private async Task<int> GetProjectCountAsync(CancellationToken cancellationToken)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
        return await dbContext.Projects.AsNoTracking().CountAsync(cancellationToken);
    }

    private async Task<IReadOnlyList<UserResponse>> GetRecentUsersAsync(
        int count, CancellationToken cancellationToken)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
        return await dbContext.Users
            .AsNoTracking()
            .OrderByDescending(u => u.CreatedAt)
            .Take(count)
            .Select(u => new UserResponse(
                u.Id, u.Email, u.DisplayName, u.CreatedAt, u.UpdatedAt))
            .ToListAsync(cancellationToken);
    }

    private async Task<IReadOnlyList<ProjectResponse>> GetActiveProjectsAsync(
        int count, CancellationToken cancellationToken)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
        return await dbContext.Projects
            .AsNoTracking()
            .OrderByDescending(p => p.CreatedAt)
            .Take(count)
            .Select(p => new ProjectResponse(p.Id, p.Name, p.Description))
            .ToListAsync(cancellationToken);
    }

### Parallel Batch Processing

    public async Task<int> ProcessUsersInBatchesAsync(
        IReadOnlyList<Guid> userIds, CancellationToken cancellationToken = default)
    {
        // Process in parallel batches of 10
        var batches = userIds.Chunk(10);
        var tasks = batches.Select(batch => ProcessBatchAsync(batch, cancellationToken));
        var results = await Task.WhenAll(tasks);
        return results.Sum();
    }

    private async Task<int> ProcessBatchAsync(
        IEnumerable<Guid> userIds, CancellationToken cancellationToken)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

        return await dbContext.Users
            .Where(u => userIds.Contains(u.Id))
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(u => u.IsActive, true),
                cancellationToken);
    }

---

## Base Entity Pattern

    public abstract class BaseEntity
    {
        public Guid Id { get; init; }
        public DateTimeOffset CreatedAt { get; init; }
        public DateTimeOffset? UpdatedAt { get; set; }
    }

---

## Entity Pattern

    public sealed class User : BaseEntity
    {
        public required string Email { get; set; }
        public required string DisplayName { get; set; }
        public bool IsActive { get; set; } = true;

        // Navigation properties
        public ICollection<Project> Projects { get; init; } = [];
    }

    public sealed class Project : BaseEntity
    {
        public required string Name { get; set; }
        public string? Description { get; set; }

        // Foreign key
        public Guid OwnerId { get; init; }

        // Navigation property
        public User Owner { get; init; } = null!;
    }

Entity rules:

- Use `required` modifier for properties that must always have a value
- Use `init` for properties set only during creation (Id, CreatedAt, foreign keys)
- Use `set` for properties that can be updated
- Use `= []` for collection navigation properties (C# 12)
- Use `= null!` for reference navigation properties (EF Core will populate)
- Mark entity classes as `sealed` unless inheritance is needed

---

## Entity Configuration Pattern

ALWAYS create a separate configuration class for each entity.
NEVER configure entities directly in OnModelCreating.

### PostgreSQL Configuration

    public sealed class UserConfiguration : IEntityTypeConfiguration<User>
    {
        public void Configure(EntityTypeBuilder<User> builder)
        {
            builder.ToTable("users");

            builder.HasKey(u => u.Id);
            builder.Property(u => u.Id)
                .HasColumnName("id")
                .HasDefaultValueSql("gen_random_uuid()");

            builder.Property(u => u.Email)
                .HasColumnName("email")
                .HasMaxLength(256)
                .IsRequired();

            builder.Property(u => u.DisplayName)
                .HasColumnName("display_name")
                .HasMaxLength(100)
                .IsRequired();

            builder.Property(u => u.IsActive)
                .HasColumnName("is_active")
                .HasDefaultValue(true);

            builder.Property(u => u.CreatedAt)
                .HasColumnName("created_at")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            builder.Property(u => u.UpdatedAt)
                .HasColumnName("updated_at");

            builder.HasIndex(u => u.Email)
                .IsUnique()
                .HasDatabaseName("ix_users_email");

            builder.HasMany(u => u.Projects)
                .WithOne(p => p.Owner)
                .HasForeignKey(p => p.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }

### SQL Server Configuration

    public sealed class UserConfiguration : IEntityTypeConfiguration<User>
    {
        public void Configure(EntityTypeBuilder<User> builder)
        {
            builder.ToTable("Users");

            builder.HasKey(u => u.Id);
            builder.Property(u => u.Id)
                .HasDefaultValueSql("NEWSEQUENTIALID()");

            builder.Property(u => u.Email)
                .HasMaxLength(256)
                .IsRequired();

            builder.Property(u => u.DisplayName)
                .HasMaxLength(100)
                .IsRequired();

            builder.Property(u => u.IsActive)
                .HasDefaultValue(true);

            builder.Property(u => u.CreatedAt)
                .HasDefaultValueSql("GETUTCDATE()");

            builder.HasIndex(u => u.Email)
                .IsUnique();

            builder.HasMany(u => u.Projects)
                .WithOne(p => p.Owner)
                .HasForeignKey(p => p.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }

---

## Query Patterns

Every query method creates its own DbContext via the factory.

### Query with Related Data (Split Query)

    public async Task<UserWithProjectsResponse?> GetWithProjectsAsync(
        Guid id, CancellationToken cancellationToken = default)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

        return await dbContext.Users
            .AsNoTracking()
            .AsSplitQuery()
            .Include(u => u.Projects)
            .Where(u => u.Id == id)
            .Select(u => new UserWithProjectsResponse(
                u.Id,
                u.Email,
                u.DisplayName,
                u.Projects.Select(p => new ProjectResponse(
                    p.Id,
                    p.Name,
                    p.Description)).ToList()))
            .FirstOrDefaultAsync(cancellationToken);
    }

### Filtered Query with Search

    public async Task<PagedResult<UserResponse>> SearchAsync(
        string? searchTerm, int page, int pageSize,
        CancellationToken cancellationToken = default)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

        var query = dbContext.Users.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(searchTerm))
        {
            var normalizedSearch = searchTerm.Trim().ToLower();
            query = query.Where(u =>
                u.Email.ToLower().Contains(normalizedSearch) ||
                u.DisplayName.ToLower().Contains(normalizedSearch));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(u => u.DisplayName)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(u => new UserResponse(
                u.Id, u.Email, u.DisplayName, u.CreatedAt, u.UpdatedAt))
            .ToListAsync(cancellationToken);

        return new PagedResult<UserResponse>(items, totalCount, page, pageSize);
    }

### Bulk Operations

    public async Task<int> DeactivateInactiveUsersAsync(
        DateTimeOffset inactiveSince, CancellationToken cancellationToken = default)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

        return await dbContext.Users
            .Where(u => u.IsActive && u.CreatedAt < inactiveSince)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(u => u.IsActive, false),
                cancellationToken);
    }

    public async Task<int> DeleteInactiveUsersAsync(
        CancellationToken cancellationToken = default)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

        return await dbContext.Users
            .Where(u => !u.IsActive)
            .ExecuteDeleteAsync(cancellationToken);
    }

### Check Existence

    public async Task<bool> ExistsAsync(
        Guid id, CancellationToken cancellationToken = default)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

        return await dbContext.Users
            .AsNoTracking()
            .AnyAsync(u => u.Id == id, cancellationToken);
    }

    public async Task<bool> EmailExistsAsync(
        string email, CancellationToken cancellationToken = default)
    {
        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);

        return await dbContext.Users
            .AsNoTracking()
            .AnyAsync(u => u.Email == email, cancellationToken);
    }

---

## Design Time Factory Pattern

Required for running migrations from a separate project:

    public sealed class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
    {
        public AppDbContext CreateDbContext(string[] args)
        {
            var configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json")
                .AddJsonFile("appsettings.Development.json", optional: true)
                .AddUserSecrets<AppDbContextFactory>(optional: true)
                .Build();

            var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
            optionsBuilder.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));

            return new AppDbContext(optionsBuilder.Options);
        }
    }

---

## Migration Commands

Create a new migration:

    dotnet ef migrations add AddUsersTable --project src/MyApp.Infrastructure --startup-project src/MyApp.Api

Apply migrations:

    dotnet ef database update --project src/MyApp.Infrastructure --startup-project src/MyApp.Api

Remove last migration (if not applied):

    dotnet ef migrations remove --project src/MyApp.Infrastructure --startup-project src/MyApp.Api

Generate idempotent SQL script (for production deployments):

    dotnet ef migrations script --project src/MyApp.Infrastructure --startup-project src/MyApp.Api --idempotent --output migrations.sql

---

## Background Service Pattern with Factory

IDbContextFactory works perfectly with background services where scoped DbContext fails:

    public sealed class UserCleanupService(
        IDbContextFactory<AppDbContext> dbContextFactory,
        ILogger<UserCleanupService> logger) : BackgroundService
    {
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await using var dbContext = await dbContextFactory.CreateDbContextAsync(stoppingToken);

                    var cutoff = DateTimeOffset.UtcNow.AddDays(-90);
                    var deleted = await dbContext.Users
                        .Where(u => !u.IsActive && u.UpdatedAt < cutoff)
                        .ExecuteDeleteAsync(stoppingToken);

                    if (deleted > 0)
                    {
                        logger.LogInformation("Cleaned up {Count} inactive users", deleted);
                    }
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Error during user cleanup");
                }

                await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
            }
        }
    }

---

## Rules Summary

### Factory Rules

1. ALWAYS register DbContext using `AddDbContextFactory` — NEVER use `AddDbContext`
2. ALWAYS inject `IDbContextFactory<AppDbContext>` — NEVER inject `AppDbContext` directly
3. ALWAYS create DbContext with `await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken)`
4. ALWAYS dispose DbContext after use (the `await using` statement handles this)
5. ALWAYS create a NEW DbContext for each operation or logical unit of work
6. NEVER share a DbContext instance across parallel operations
7. NEVER hold a DbContext reference beyond the scope of a single method

### Parallel Execution Rules

8. For independent queries, use `Task.WhenAll` with separate DbContext instances per query
9. For batch processing, use `.Chunk()` with a separate DbContext per batch
10. Each parallel branch MUST create its own DbContext from the factory

### Entity Rules

11. ALWAYS inherit from a BaseEntity class with Id, CreatedAt, UpdatedAt
12. ALWAYS use `required` modifier for non-nullable properties that must be set
13. ALWAYS use `init` for properties set only during creation
14. ALWAYS use `sealed` on entity classes unless inheritance is needed
15. ALWAYS initialize collection navigation properties with `= []`
16. ALWAYS initialize reference navigation properties with `= null!`

### Configuration Rules

17. ALWAYS create a separate IEntityTypeConfiguration class per entity
18. NEVER configure entities directly in OnModelCreating
19. ALWAYS use ApplyConfigurationsFromAssembly for auto-discovery
20. ALWAYS configure max lengths on string properties
21. ALWAYS add unique indexes for natural keys (email, username, etc.)
22. ALWAYS use DeleteBehavior.Restrict for foreign keys

### PostgreSQL-Specific Rules

23. Use snake_case for table names (users, user_profiles)
24. Use snake_case for column names (created_at, display_name)
25. Use `gen_random_uuid()` for UUID generation
26. Use `CURRENT_TIMESTAMP` for default timestamps
27. Use `jsonb` column type for JSON data (not json)

### SQL Server-Specific Rules

28. Use PascalCase for table names (Users, UserProfiles)
29. Use PascalCase for column names (CreatedAt, DisplayName)
30. Use `NEWSEQUENTIALID()` for GUID generation
31. Use `GETUTCDATE()` for default timestamps

### Query Rules

32. ALWAYS use `AsNoTracking()` for read-only queries
33. ALWAYS use `Select()` projection to fetch only needed columns
34. ALWAYS include pagination (Skip/Take) for list queries
35. ALWAYS include `CancellationToken` in all async methods
36. ALWAYS use `AsSplitQuery()` when including multiple collection navigations
37. ALWAYS use `ExecuteUpdateAsync` / `ExecuteDeleteAsync` for bulk operations
38. ALWAYS use `AnyAsync` instead of `CountAsync > 0` for existence checks
39. NEVER use string interpolation in FromSqlRaw — use FromSqlInterpolated
40. NEVER load entire entities when only a few properties are needed — use Select projection
