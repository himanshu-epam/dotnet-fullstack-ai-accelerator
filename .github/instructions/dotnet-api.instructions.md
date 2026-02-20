---
applyTo: "**/*.cs,**/Program.cs,**/Startup.cs,**/*Controller*.cs,**/*Endpoint*.cs"
---

# ASP.NET Core API Development Instructions

## Architecture Patterns

- Use **Minimal APIs** for simple endpoints, **Controllers** for complex resource management
- Group related endpoints using `MapGroup()` for Minimal APIs
- Use `[Route("api/v1/[controller]")]` for controllers
- Implement the **mediator pattern** (MediatR) only when CQRS complexity warrants it
- For simple CRUD, use a service class injected into the controller/endpoint
- Follow the project structure defined in `.specify/memory/constitution.md` Section 1.2

---

## Program.cs Structure

Follow this ordering in Program.cs. Each section is clearly separated with comments:

    var builder = WebApplication.CreateBuilder(args);

    // ─── 1. Configuration ───
    builder.Services.AddOptions<AppSettings>()
        .BindConfiguration("App")
        .ValidateDataAnnotations()
        .ValidateOnStart();

    // ─── 2. Authentication and Authorization ───
    builder.Services.AddMicrosoftIdentityWebApiAuthentication(builder.Configuration);
    builder.Services.AddAuthorizationBuilder()
        .AddPolicy("RequireAdmin", policy => policy.RequireRole("Admin"))
        .AddPolicy("RequireUser", policy => policy.RequireRole("User", "Admin"));

    // ─── 3. OpenAPI and Scalar ───
    builder.Services.AddOpenApi(options =>
    {
        options.AddDocumentTransformer<OAuth2SecuritySchemeTransformer>();
    });

    // ─── 4. Application Services ───
    builder.Services.AddScoped<IUserService, UserService>();

    // ─── 5. Data Access ───
    builder.Services.AddDbContext<AppDbContext>(options =>
        options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

    // ─── 6. Health Checks ───
    builder.Services.AddHealthChecks()
        .AddNpgSql(builder.Configuration.GetConnectionString("DefaultConnection")!);

    // ─── 7. Rate Limiting ───
    builder.Services.AddRateLimiter(options =>
    {
        options.AddFixedWindowLimiter("fixed", config =>
        {
            config.PermitLimit = 100;
            config.Window = TimeSpan.FromMinutes(1);
        });
    });

    // ─── 8. CORS ───
    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(policy =>
        {
            policy.WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()!)
                .AllowAnyHeader()
                .AllowAnyMethod();
        });
    });

    var app = builder.Build();

    // ─── Middleware Pipeline (ORDER MATTERS) ───
    app.UseHttpsRedirection();
    app.UseCors();
    app.UseAuthentication();
    app.UseAuthorization();
    app.UseRateLimiter();

    // ─── Endpoints ───
    app.MapOpenApi();
    app.MapScalarApiReference("/scalar/v1");
    app.MapHealthChecks("/health");
    app.MapHealthChecks("/ready");
    app.MapControllers();

    app.Run();

---

## Controller Pattern

When creating a controller, follow this exact pattern:

    [ApiController]
    [Route("api/v1/[controller]")]
    [Authorize]
    [Produces("application/json")]
    [Tags("Users")]
    public sealed class UsersController(
        IUserService userService,
        ILogger<UsersController> logger) : ControllerBase
    {
        /// <summary>
        /// Gets a paginated list of users.
        /// </summary>
        /// <param name="page">Page number (1-based).</param>
        /// <param name="pageSize">Number of items per page.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>A paginated list of users.</returns>
        [HttpGet]
        [ProducesResponseType(typeof(PagedResult<UserResponse>), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken cancellationToken = default)
        {
            logger.LogInformation("Retrieving users page {Page} with size {PageSize}", page, pageSize);
            var result = await userService.GetAllAsync(page, pageSize, cancellationToken);
            return Ok(result);
        }

        /// <summary>
        /// Gets a user by their unique identifier.
        /// </summary>
        /// <param name="id">The user ID.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>The user if found.</returns>
        [HttpGet("{id:guid}")]
        [ProducesResponseType(typeof(UserResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetById(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            var result = await userService.GetByIdAsync(id, cancellationToken);
            if (result is null)
            {
                return NotFound();
            }
            return Ok(result);
        }

        /// <summary>
        /// Creates a new user.
        /// </summary>
        /// <param name="request">The user creation request.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>The created user.</returns>
        [HttpPost]
        [ProducesResponseType(typeof(UserResponse), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
        public async Task<IActionResult> Create(
            [FromBody] CreateUserRequest request,
            CancellationToken cancellationToken = default)
        {
            logger.LogInformation("Creating user with email {Email}", request.Email);
            var result = await userService.CreateAsync(request, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        /// <summary>
        /// Updates an existing user.
        /// </summary>
        /// <param name="id">The user ID.</param>
        /// <param name="request">The user update request.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>The updated user.</returns>
        [HttpPut("{id:guid}")]
        [ProducesResponseType(typeof(UserResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> Update(
            Guid id,
            [FromBody] UpdateUserRequest request,
            CancellationToken cancellationToken = default)
        {
            var result = await userService.UpdateAsync(id, request, cancellationToken);
            if (result is null)
            {
                return NotFound();
            }
            return Ok(result);
        }

        /// <summary>
        /// Deletes a user by their unique identifier.
        /// </summary>
        /// <param name="id">The user ID.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>No content if successful.</returns>
        [HttpDelete("{id:guid}")]
        [Authorize(Policy = "RequireAdmin")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> Delete(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            logger.LogInformation("Deleting user {UserId}", id);
            var deleted = await userService.DeleteAsync(id, cancellationToken);
            if (!deleted)
            {
                return NotFound();
            }
            return NoContent();
        }
    }

---

## DTO Pattern

Use record types for all request and response DTOs:

    // Requests
    public sealed record CreateUserRequest(
        [Required] string Email,
        [Required] [StringLength(100)] string DisplayName);

    public sealed record UpdateUserRequest(
        [Required] [StringLength(100)] string DisplayName);

    // Responses
    public sealed record UserResponse(
        Guid Id,
        string Email,
        string DisplayName,
        DateTimeOffset CreatedAt,
        DateTimeOffset? UpdatedAt);

    // Paged result wrapper
    public sealed record PagedResult<T>(
        IReadOnlyList<T> Items,
        int TotalCount,
        int Page,
        int PageSize)
    {
        public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);
        public bool HasNextPage => Page < TotalPages;
        public bool HasPreviousPage => Page > 1;
    }

---

## Service Interface Pattern

    public interface IUserService
    {
        Task<PagedResult<UserResponse>> GetAllAsync(int page, int pageSize, CancellationToken cancellationToken = default);
        Task<UserResponse?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
        Task<UserResponse> CreateAsync(CreateUserRequest request, CancellationToken cancellationToken = default);
        Task<UserResponse?> UpdateAsync(Guid id, UpdateUserRequest request, CancellationToken cancellationToken = default);
        Task<bool> DeleteAsync(Guid id, CancellationToken cancellationToken = default);
    }

---

## Service Implementation Pattern

    public sealed class UserService(
        AppDbContext dbContext,
        ILogger<UserService> logger) : IUserService
    {
        public async Task<PagedResult<UserResponse>> GetAllAsync(
            int page, int pageSize, CancellationToken cancellationToken = default)
        {
            var totalCount = await dbContext.Users
                .AsNoTracking()
                .CountAsync(cancellationToken);

            var items = await dbContext.Users
                .AsNoTracking()
                .OrderBy(u => u.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(u => new UserResponse(u.Id, u.Email, u.DisplayName, u.CreatedAt, u.UpdatedAt))
                .ToListAsync(cancellationToken);

            return new PagedResult<UserResponse>(items, totalCount, page, pageSize);
        }

        public async Task<UserResponse?> GetByIdAsync(
            Guid id, CancellationToken cancellationToken = default)
        {
            return await dbContext.Users
                .AsNoTracking()
                .Where(u => u.Id == id)
                .Select(u => new UserResponse(u.Id, u.Email, u.DisplayName, u.CreatedAt, u.UpdatedAt))
                .FirstOrDefaultAsync(cancellationToken);
        }

        public async Task<UserResponse> CreateAsync(
            CreateUserRequest request, CancellationToken cancellationToken = default)
        {
            var user = new User
            {
                Email = request.Email,
                DisplayName = request.DisplayName
            };

            dbContext.Users.Add(user);
            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogInformation("Created user {UserId} with email {Email}", user.Id, user.Email);

            return new UserResponse(user.Id, user.Email, user.DisplayName, user.CreatedAt, user.UpdatedAt);
        }

        public async Task<UserResponse?> UpdateAsync(
            Guid id, UpdateUserRequest request, CancellationToken cancellationToken = default)
        {
            var user = await dbContext.Users.FindAsync([id], cancellationToken);
            if (user is null)
            {
                return null;
            }

            user.DisplayName = request.DisplayName;
            user.UpdatedAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogInformation("Updated user {UserId}", user.Id);

            return new UserResponse(user.Id, user.Email, user.DisplayName, user.CreatedAt, user.UpdatedAt);
        }

        public async Task<bool> DeleteAsync(
            Guid id, CancellationToken cancellationToken = default)
        {
            var deleted = await dbContext.Users
                .Where(u => u.Id == id)
                .ExecuteDeleteAsync(cancellationToken);

            return deleted > 0;
        }
    }

---

## Global Exception Handling Middleware

    public sealed class GlobalExceptionHandlerMiddleware(
        RequestDelegate next,
        ILogger<GlobalExceptionHandlerMiddleware> logger)
    {
        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await next(context);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhandled exception for {Method}{Path}", context.Request.Method, context.Request.Path);

                context.Response.StatusCode = StatusCodes.Status500InternalServerError;
                context.Response.ContentType = "application/problem+json";

                var problemDetails = new ProblemDetails
                {
                    Status = StatusCodes.Status500InternalServerError,
                    Title = "An unexpected error occurred",
                    Type = "https://tools.ietf.org/html/rfc7231#section-6.6.1"
                };

                await context.Response.WriteAsJsonAsync(problemDetails);
            }
        }
    }

Register in Program.cs:

    app.UseMiddleware<GlobalExceptionHandlerMiddleware>();

---

## Rules Summary

1. ALWAYS use primary constructors for DI injection in controllers and services
2. ALWAYS add `sealed` modifier to controllers and services
3. ALWAYS include CancellationToken as the last parameter on async methods
4. ALWAYS add XML documentation comments on all public controller actions
5. ALWAYS add `[ProducesResponseType]` for every possible status code
6. ALWAYS use `[Authorize]` at controller level and `[AllowAnonymous]` for exceptions
7. ALWAYS add `[Tags]` attribute for Scalar grouping
8. ALWAYS add route constraints on parameters (e.g., `{id:guid}`)
9. ALWAYS return `CreatedAtAction` for POST operations (201 with Location header)
10. ALWAYS use `AsNoTracking()` for read-only database queries
11. ALWAYS include pagination for list endpoints
12. ALWAYS use structured logging with named placeholders (e.g., {UserId} not string interpolation)
13. NEVER use `Console.WriteLine` — use `ILogger<T>` instead
14. NEVER use `.Result` or `.Wait()` on async operations
15. NEVER return 200 for creation operations — use 201 Created
