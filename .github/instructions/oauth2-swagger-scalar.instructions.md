---
applyTo: "**/*Scalar*,**/*OpenApi*,**/*Swagger*,**/*SecurityScheme*,**/*DocumentTransformer*,**/Program.cs"
---

# Scalar + OAuth2 Integration Instructions

## Overview

We use **Scalar** instead of Swagger UI for API documentation.
Scalar provides a modern, fast, and beautiful API reference with built-in OAuth2 support.
This allows developers to authenticate directly from the docs and test API endpoints.

## Why Scalar over Swagger UI

| Feature         | Swagger UI             | Scalar            |
| --------------- | ---------------------- | ----------------- |
| Modern UI       | ❌ Dated               | ✅ Clean, fast    |
| OAuth2 built-in | ⚠️ Complex config      | ✅ Simple config  |
| Dark mode       | ❌                     | ✅                |
| Search          | ❌ Basic               | ✅ Full-text      |
| Performance     | ⚠️ Slow on large specs | ✅ Fast           |
| Customization   | ⚠️ Limited             | ✅ Themes, layout |

## NuGet Packages Required

- Microsoft.AspNetCore.OpenApi (built into .NET 9, add manually for .NET 8)
- Scalar.AspNetCore

---

## Basic Setup in Program.cs

### Step 1: Register OpenAPI with Security Scheme

    // ─── OpenAPI + Security Scheme ───
    builder.Services.AddOpenApi(options =>
    {
        options.AddDocumentTransformer<OAuth2SecuritySchemeTransformer>();
        options.AddDocumentTransformer<ApiInfoTransformer>();
    });

### Step 2: Map OpenAPI and Scalar Endpoints

    // ─── Map OpenAPI JSON and Scalar UI ───
    if (app.Environment.IsDevelopment() || app.Environment.IsStaging())
    {
        app.MapOpenApi();
        app.MapScalarApiReference("/scalar/v1", options =>
        {
            options
                .WithTitle("My Application API")
                .WithTheme(ScalarTheme.Default)
                .WithDarkModeToggle(true)
                .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient)
                .WithPreferredScheme("OAuth2")
                .WithOAuth2BearerToken(new OAuth2BearerToken
                {
                    Token = string.Empty
                });
        });
    }

### Complete Program.cs Section

    var builder = WebApplication.CreateBuilder(args);

    // ─── Authentication ───
    builder.Services
        .AddMicrosoftIdentityWebApiAuthentication(builder.Configuration, "AzureAd");
    builder.Services.AddAuthorization();

    // ─── OpenAPI ───
    builder.Services.AddOpenApi(options =>
    {
        options.AddDocumentTransformer<OAuth2SecuritySchemeTransformer>();
        options.AddDocumentTransformer<ApiInfoTransformer>();
    });

    // ─── Application Services ───
    builder.Services.AddControllers();

    var app = builder.Build();

    // ─── Middleware ───
    app.UseHttpsRedirection();
    app.UseAuthentication();
    app.UseAuthorization();

    // ─── OpenAPI + Scalar (non-production or behind auth) ───
    app.MapOpenApi();
    app.MapScalarApiReference("/scalar/v1", options =>
    {
        options
            .WithTitle($"{builder.Environment.ApplicationName} API")
            .WithTheme(ScalarTheme.Default)
            .WithDarkModeToggle(true)
            .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient)
            .WithPreferredScheme("OAuth2");
    });

    // ─── Endpoints ───
    app.MapHealthChecks("/health");
    app.MapHealthChecks("/ready");
    app.MapControllers();

    app.Run();

---

## OAuth2 Security Scheme Transformer

This transformer adds the OAuth2 security definition to the OpenAPI document
so Scalar shows the authenticate button with Entra ID login.

    using Microsoft.AspNetCore.Authentication;
    using Microsoft.AspNetCore.OpenApi;
    using Microsoft.OpenApi.Models;

    public sealed class OAuth2SecuritySchemeTransformer(
        IConfiguration configuration) : IOpenApiDocumentTransformer
    {
        public Task TransformAsync(
            OpenApiDocument document,
            OpenApiDocumentTransformerContext context,
            CancellationToken cancellationToken)
        {
            var tenantId = configuration["AzureAd:TenantId"];
            var clientId = configuration["AzureAd:ClientId"];
            var audience = configuration["AzureAd:Audience"] ?? $"api://{clientId}";
            var authority = $"https://login.microsoftonline.com/{tenantId}";

            var securityScheme = new OpenApiSecurityScheme
            {
                Type = SecuritySchemeType.OAuth2,
                Description = "Azure Entra ID OAuth2 Authentication",
                Flows = new OpenApiOAuthFlows
                {
                    AuthorizationCode = new OpenApiOAuthFlow
                    {
                        AuthorizationUrl = new Uri($"{authority}/oauth2/v2.0/authorize"),
                        TokenUrl = new Uri($"{authority}/oauth2/v2.0/token"),
                        Scopes = new Dictionary<string, string>
                        {
                            { $"{audience}/.default", "Access the API" }
                        }
                    }
                }
            };

            document.Components ??= new OpenApiComponents();
            document.Components.SecuritySchemes = new Dictionary<string, OpenApiSecurityScheme>
            {
                ["OAuth2"] = securityScheme
            };

            // Apply security requirement globally to all operations
            document.SecurityRequirements.Add(new OpenApiSecurityRequirement
            {
                [new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference
                    {
                        Id = "OAuth2",
                        Type = ReferenceType.SecurityScheme
                    }
                }] = [$"{audience}/.default"]
            });

            return Task.CompletedTask;
        }
    }

---

## API Info Transformer

This transformer sets the API title, description, version, and contact info
in the OpenAPI document.

    public sealed class ApiInfoTransformer(
        IConfiguration configuration,
        IWebHostEnvironment environment) : IOpenApiDocumentTransformer
    {
        public Task TransformAsync(
            OpenApiDocument document,
            OpenApiDocumentTransformerContext context,
            CancellationToken cancellationToken)
        {
            document.Info = new OpenApiInfo
            {
                Title = $"{environment.ApplicationName} API",
                Description = configuration["ApiInfo:Description"]
                    ?? "API documentation with OAuth2 authentication via Azure Entra ID.",
                Version = configuration["ApiInfo:Version"] ?? "v1",
                Contact = new OpenApiContact
                {
                    Name = configuration["ApiInfo:ContactName"] ?? "API Team",
                    Email = configuration["ApiInfo:ContactEmail"]
                }
            };

            return Task.CompletedTask;
        }
    }

### appsettings.json

    {
      "ApiInfo": {
        "Description": "My Application API — Manage users, projects, and resources.",
        "Version": "v1",
        "ContactName": "Platform Team",
        "ContactEmail": "platform-team@example.com"
      }
    }

---

## Controller Annotations for Scalar Documentation

Proper annotations ensure Scalar generates complete, accurate documentation.

### Complete Controller Example

    /// <summary>
    /// Manages user resources.
    /// </summary>
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
        /// <param name="page">Page number (1-based). Default: 1.</param>
        /// <param name="pageSize">Items per page (1-100). Default: 20.</param>
        /// <param name="search">Optional search term for email or display name.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>A paginated list of users.</returns>
        /// <response code="200">Returns the paginated list of users.</response>
        /// <response code="401">If the request is not authenticated.</response>
        [HttpGet]
        [ProducesResponseType(typeof(PagedResult<UserResponse>), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? search = null,
            CancellationToken cancellationToken = default)
        {
            var result = await userService.SearchAsync(search, page, pageSize, cancellationToken);
            return Ok(result);
        }

        /// <summary>
        /// Gets a user by their unique identifier.
        /// </summary>
        /// <param name="id">The unique user identifier.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>The user details.</returns>
        /// <response code="200">Returns the user details.</response>
        /// <response code="401">If the request is not authenticated.</response>
        /// <response code="404">If the user is not found.</response>
        [HttpGet("{id:guid}")]
        [ProducesResponseType(typeof(UserResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            var result = await userService.GetByIdAsync(id, cancellationToken);
            return result is null ? NotFound() : Ok(result);
        }

        /// <summary>
        /// Creates a new user.
        /// </summary>
        /// <param name="request">The user creation details.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>The newly created user.</returns>
        /// <response code="201">Returns the created user with location header.</response>
        /// <response code="400">If the request body is invalid.</response>
        /// <response code="401">If the request is not authenticated.</response>
        /// <response code="409">If a user with the same email already exists.</response>
        [HttpPost]
        [ProducesResponseType(typeof(UserResponse), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
        public async Task<IActionResult> Create(
            [FromBody] CreateUserRequest request,
            CancellationToken cancellationToken = default)
        {
            var result = await userService.CreateAsync(request, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        /// <summary>
        /// Updates an existing user.
        /// </summary>
        /// <param name="id">The unique user identifier.</param>
        /// <param name="request">The user update details.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>The updated user.</returns>
        /// <response code="200">Returns the updated user.</response>
        /// <response code="400">If the request body is invalid.</response>
        /// <response code="401">If the request is not authenticated.</response>
        /// <response code="404">If the user is not found.</response>
        [HttpPut("{id:guid}")]
        [ProducesResponseType(typeof(UserResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Update(
            Guid id,
            [FromBody] UpdateUserRequest request,
            CancellationToken cancellationToken = default)
        {
            var result = await userService.UpdateAsync(id, request, cancellationToken);
            return result is null ? NotFound() : Ok(result);
        }

        /// <summary>
        /// Deletes a user. Requires Admin role.
        /// </summary>
        /// <param name="id">The unique user identifier.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>No content if successful.</returns>
        /// <response code="204">User was successfully deleted.</response>
        /// <response code="401">If the request is not authenticated.</response>
        /// <response code="403">If the user does not have the Admin role.</response>
        /// <response code="404">If the user is not found.</response>
        [HttpDelete("{id:guid}")]
        [Authorize(Policy = "RequireAdmin")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Delete(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            var deleted = await userService.DeleteAsync(id, cancellationToken);
            return deleted ? NoContent() : NotFound();
        }
    }

---

## Minimal API Annotations for Scalar

If using Minimal APIs instead of controllers:

    var users = app.MapGroup("api/v1/users")
        .WithTags("Users")
        .RequireAuthorization();

    users.MapGet("/", async (
        [FromQuery] int page,
        [FromQuery] int pageSize,
        [FromQuery] string? search,
        IUserService userService,
        CancellationToken cancellationToken) =>
    {
        var result = await userService.SearchAsync(search, page, pageSize, cancellationToken);
        return Results.Ok(result);
    })
    .WithName("GetAllUsers")
    .WithSummary("Gets a paginated list of users")
    .WithDescription("Returns users matching the optional search term with pagination.")
    .Produces<PagedResult<UserResponse>>(StatusCodes.Status200OK)
    .ProducesProblem(StatusCodes.Status401Unauthorized);

    users.MapGet("/{id:guid}", async (
        Guid id,
        IUserService userService,
        CancellationToken cancellationToken) =>
    {
        var result = await userService.GetByIdAsync(id, cancellationToken);
        return result is null ? Results.NotFound() : Results.Ok(result);
    })
    .WithName("GetUserById")
    .WithSummary("Gets a user by ID")
    .Produces<UserResponse>(StatusCodes.Status200OK)
    .ProducesProblem(StatusCodes.Status404NotFound)
    .ProducesProblem(StatusCodes.Status401Unauthorized);

    users.MapPost("/", async (
        [FromBody] CreateUserRequest request,
        IUserService userService,
        CancellationToken cancellationToken) =>
    {
        var result = await userService.CreateAsync(request, cancellationToken);
        return Results.CreatedAtRoute("GetUserById", new { id = result.Id }, result);
    })
    .WithName("CreateUser")
    .WithSummary("Creates a new user")
    .Produces<UserResponse>(StatusCodes.Status201Created)
    .ProducesValidationProblem()
    .ProducesProblem(StatusCodes.Status401Unauthorized)
    .ProducesProblem(StatusCodes.Status409Conflict);

    users.MapDelete("/{id:guid}", async (
        Guid id,
        IUserService userService,
        CancellationToken cancellationToken) =>
    {
        var deleted = await userService.DeleteAsync(id, cancellationToken);
        return deleted ? Results.NoContent() : Results.NotFound();
    })
    .WithName("DeleteUser")
    .WithSummary("Deletes a user (Admin only)")
    .RequireAuthorization("RequireAdmin")
    .Produces(StatusCodes.Status204NoContent)
    .ProducesProblem(StatusCodes.Status401Unauthorized)
    .ProducesProblem(StatusCodes.Status403Forbidden)
    .ProducesProblem(StatusCodes.Status404NotFound);

---

## DTO Documentation for Scalar

Add XML documentation and validation attributes to DTOs so Scalar shows
accurate schemas with descriptions and constraints:

    /// <summary>
    /// Request to create a new user.
    /// </summary>
    public sealed record CreateUserRequest(
        /// <summary>
        /// The user's email address. Must be unique.
        /// </summary>
        /// <example>john.doe@example.com</example>
        [Required]
        [EmailAddress]
        [StringLength(256)]
        string Email,

        /// <summary>
        /// The user's display name.
        /// </summary>
        /// <example>John Doe</example>
        [Required]
        [StringLength(100, MinimumLength = 2)]
        string DisplayName);

    /// <summary>
    /// User details response.
    /// </summary>
    public sealed record UserResponse(
        /// <summary>
        /// The unique user identifier.
        /// </summary>
        /// <example>3fa85f64-5717-4562-b3fc-2c963f66afa6</example>
        Guid Id,

        /// <summary>
        /// The user's email address.
        /// </summary>
        /// <example>john.doe@example.com</example>
        string Email,

        /// <summary>
        /// The user's display name.
        /// </summary>
        /// <example>John Doe</example>
        string DisplayName,

        /// <summary>
        /// When the user was created.
        /// </summary>
        DateTimeOffset CreatedAt,

        /// <summary>
        /// When the user was last updated. Null if never updated.
        /// </summary>
        DateTimeOffset? UpdatedAt);

Enable XML documentation generation in the .csproj file:

    <PropertyGroup>
      <GenerateDocumentationFile>true</GenerateDocumentationFile>
      <NoWarn>$(NoWarn);1591</NoWarn>
    </PropertyGroup>

---

## Azure Entra ID App Registration for Scalar OAuth2

For Scalar OAuth2 to work, the Entra ID App Registration must be configured correctly.

### Required App Registration Settings

1. **Authentication** tab:
   - Add a **Single-page application** platform
   - Add redirect URI: `https://localhost:7001/scalar/v1/oauth2-redirect`
   - Add redirect URI: `https://your-app.example.com/scalar/v1/oauth2-redirect`
   - Enable **Access tokens** and **ID tokens** under Implicit grant (for Scalar)
   - Check **Accounts in this organizational directory only**

2. **API permissions** tab:
   - Add permission: Microsoft Graph > User.Read (delegated)

3. **Expose an API** tab:
   - Set Application ID URI: `api://<CLIENT_ID>`
   - Add scope: `access_as_user`
     - Who can consent: Admins and users
     - Admin consent display name: Access the API
     - Admin consent description: Allows the app to access the API on behalf of the signed-in user

4. **App roles** tab:
   - Add roles: Admin, User, Reader
   - Allowed member types: Users/Groups

### Redirect URI Pattern

The Scalar OAuth2 redirect URI follows this pattern:

    https://<your-host>/scalar/v1/oauth2-redirect

For local development:

    https://localhost:7001/scalar/v1/oauth2-redirect

For deployed environments:

    https://api.example.com/scalar/v1/oauth2-redirect

## ALWAYS add both local and production redirect URIs to the App Registration.

## Scalar Configuration Per Environment

### Development — Full Access

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
        app.MapScalarApiReference("/scalar/v1", options =>
        {
            options
                .WithTitle($"{builder.Environment.ApplicationName} API - Development")
                .WithTheme(ScalarTheme.Default)
                .WithDarkModeToggle(true)
                .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient)
                .WithPreferredScheme("OAuth2");
        });
    }

### Staging — Behind Authentication

    if (app.Environment.IsStaging())
    {
        app.MapOpenApi().RequireAuthorization();
        app.MapScalarApiReference("/scalar/v1", options =>
        {
            options
                .WithTitle($"{builder.Environment.ApplicationName} API - Staging")
                .WithTheme(ScalarTheme.Moon)
                .WithPreferredScheme("OAuth2");
        }).RequireAuthorization("RequireAdmin");
    }

### Production — Disabled or Admin Only

    if (app.Environment.IsProduction())
    {
        // Option 1: Completely disabled
        // Do not map OpenApi or Scalar endpoints

        // Option 2: Admin only (if needed for production debugging)
        app.MapOpenApi().RequireAuthorization("RequireAdmin");
        app.MapScalarApiReference("/scalar/v1", options =>
        {
            options
                .WithTitle($"{builder.Environment.ApplicationName} API - Production")
                .WithTheme(ScalarTheme.DeepSpace);
        }).RequireAuthorization("RequireAdmin");
    }

---

## Endpoint URLs

| Endpoint        | URL                        | Description                   |
| --------------- | -------------------------- | ----------------------------- |
| OpenAPI JSON    | /openapi/v1.json           | Raw OpenAPI specification     |
| Scalar UI       | /scalar/v1                 | Interactive API documentation |
| OAuth2 Redirect | /scalar/v1/oauth2-redirect | OAuth2 callback for Scalar    |
| Health          | /health                    | Liveness probe                |
| Ready           | /ready                     | Readiness probe               |

---

## Rules Summary

### Scalar Setup Rules

1. ALWAYS use Scalar instead of Swagger UI for all new projects
2. ALWAYS configure Scalar at `/scalar/v1`
3. ALWAYS serve OpenAPI JSON at `/openapi/v1.json`
4. ALWAYS add the OAuth2SecuritySchemeTransformer to enable authentication in Scalar
5. ALWAYS add the ApiInfoTransformer to provide title, description, and version
6. ALWAYS configure Scalar per environment (dev: open, staging: auth, prod: disabled or admin)

### OAuth2 Configuration Rules

7. ALWAYS use Authorization Code flow (not Implicit) in the security scheme
8. ALWAYS set correct AuthorizationUrl and TokenUrl for Entra ID v2.0 endpoints
9. ALWAYS use the `.default` scope pattern for the API audience
10. ALWAYS add the Scalar OAuth2 redirect URI to the Entra ID App Registration

### Controller Annotation Rules

11. ALWAYS add `[Produces("application/json")]` at controller level
12. ALWAYS add `[Tags("GroupName")]` for Scalar grouping
13. ALWAYS add `[ProducesResponseType]` for EVERY possible status code
14. ALWAYS add `/// <summary>` XML docs on controller actions
15. ALWAYS add `/// <param>` XML docs for all parameters
16. ALWAYS add `/// <response>` XML docs for each status code
17. ALWAYS use `[FromQuery]`, `[FromBody]`, `[FromRoute]` explicitly

### Minimal API Annotation Rules

18. ALWAYS use `.WithTags()` for Scalar grouping
19. ALWAYS use `.WithName()` for operation IDs
20. ALWAYS use `.WithSummary()` and `.WithDescription()`
21. ALWAYS use `.Produces<T>()` and `.ProducesProblem()` for response types

### DTO Documentation Rules

22. ALWAYS add `/// <summary>` on record types and properties
23. ALWAYS add `/// <example>` to show sample values in Scalar
24. ALWAYS add validation attributes ([Required], [StringLength], [
