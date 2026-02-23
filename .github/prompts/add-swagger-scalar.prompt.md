---
agent: agent
description: "Configure Scalar API reference with OAuth2 authentication replacing Swagger UI"
---

# Add Swagger/Scalar with OAuth2 Authentication

You are helping the developer configure Scalar as the API documentation UI with
OAuth2 (Azure Entra ID) authentication support, replacing the default Swagger UI.
Follow the organization's constitution at `.specify/memory/constitution.md` — specifically
Section 1 (API Design), Section 2 (Authentication), and Section 8 (Security).

## Inputs

- **Project Path**: ${input:projectPath:Path to the API project (e.g., src/MyApp.Api)}
- **Entra ID Client ID**: ${input:clientId:Azure Entra ID App Registration Client ID}
- **Entra ID Tenant ID**: ${input:tenantId:Azure Entra ID Tenant ID}
- **API Scope**: ${input:apiScope:The API scope (e.g., api://client-id/.default)}
- **API Title**: ${input:apiTitle:The display title for the API documentation}
- **API Version**: ${input:apiVersion:v1}

## Step 1 — Install Required NuGet Packages

Add the following packages to the API project:

    dotnet add src/MyApp.Api package Microsoft.AspNetCore.OpenApi
    dotnet add src/MyApp.Api package Scalar.AspNetCore

If Swagger (Swashbuckle) is currently installed, remove it:

    dotnet remove src/MyApp.Api package Swashbuckle.AspNetCore

### Why Scalar Over Swagger UI:

- Scalar provides a modern, clean UI with better developer experience
- Built-in OAuth2 authentication flow support
- Better dark mode and responsive design
- Active development and community support
- Constitution Section 1.1 mandates Scalar for all APIs

## Step 2 — Configure OpenAPI Document Generation

Update `Program.cs` to configure OpenAPI document generation with security schemes.

### Rules:

- Use `AddOpenApi()` from Microsoft.AspNetCore.OpenApi
- Add a document transformer for OAuth2/Bearer security
- Include API info with title, version, and description
- Configure the OpenAPI document to include authorization endpoints

### Add OpenAPI Configuration in Program.cs:

    // In the services configuration section (before builder.Build())

    builder.Services.AddOpenApi("{apiVersion}", options =>
    {
        options.AddDocumentTransformer((document, context, cancellationToken) =>
        {
            document.Info = new()
            {
                Title = "{apiTitle}",
                Version = "{apiVersion}",
                Description = "API documentation with OAuth2 authentication via Azure Entra ID"
            };
            return Task.CompletedTask;
        });

        options.AddDocumentTransformer<BearerSecuritySchemeTransformer>();
    });

## Step 3 — Create the Bearer Security Scheme Transformer

Create a new file `Infrastructure/OpenApi/BearerSecuritySchemeTransformer.cs` in the API project.

### Rules:

- Implement `IOpenApiDocumentTransformer`
- Configure OAuth2 Authorization Code flow with PKCE
- Use Azure Entra ID endpoints for authorization and token
- Add the Bearer security scheme to all operations
- Mark the class as `internal sealed`

### BearerSecuritySchemeTransformer:

    using Microsoft.AspNetCore.Authentication;
    using Microsoft.AspNetCore.OpenApi;
    using Microsoft.OpenApi.Models;

    namespace MyApp.Api.Infrastructure.OpenApi;

    internal sealed class BearerSecuritySchemeTransformer(
        IAuthenticationSchemeProvider authenticationSchemeProvider)
        : IOpenApiDocumentTransformer
    {
        public async Task TransformAsync(
            OpenApiDocument document,
            OpenApiDocumentTransformerContext context,
            CancellationToken cancellationToken)
        {
            var authSchemes = await authenticationSchemeProvider
                .GetAllSchemesAsync();

            if (authSchemes.Any(s => s.Name == "Bearer"))
            {
                var requirements = new Dictionary<string, OpenApiSecurityScheme>
                {
                    ["OAuth2"] = new OpenApiSecurityScheme
                    {
                        Type = SecuritySchemeType.OAuth2,
                        Description = "Azure Entra ID OAuth2 Authentication",
                        Flows = new OpenApiOAuthFlows
                        {
                            AuthorizationCode = new OpenApiOAuthFlow
                            {
                                AuthorizationUrl = new Uri(
                                    "https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/authorize"),
                                TokenUrl = new Uri(
                                    "https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token"),
                                Scopes = new Dictionary<string, string>
                                {
                                    ["{apiScope}"] = "Access the API"
                                }
                            }
                        }
                    },
                    ["Bearer"] = new OpenApiSecurityScheme
                    {
                        Type = SecuritySchemeType.Http,
                        Scheme = "bearer",
                        BearerFormat = "JWT",
                        Description = "JWT Bearer token from Azure Entra ID"
                    }
                };

                document.Components ??= new OpenApiComponents();
                document.Components.SecuritySchemes = requirements;

                foreach (var operation in document.Paths.Values
                    .SelectMany(path => path.Operations.Values))
                {
                    operation.Security.Add(new OpenApiSecurityRequirement
                    {
                        [new OpenApiSecurityScheme
                        {
                            Reference = new OpenApiReference
                            {
                                Id = "OAuth2",
                                Type = ReferenceType.SecurityScheme
                            }
                        }] = ["{apiScope}"]
                    });
                }
            }
        }
    }

## Step 4 — Configure Scalar API Reference UI

Add Scalar middleware configuration in `Program.cs` after `app.MapOpenApi()`.

### Rules:

- Map Scalar to `/scalar/{version}` path
- Configure OAuth2 with PKCE for the interactive login
- Set the API title and theme
- Enable dark mode by default
- Configure the default HTTP client
- Only expose in Development and Staging (NEVER in Production unless explicitly required)

### Scalar Configuration in Program.cs:

    // In the middleware pipeline section (after app = builder.Build())

    // Map the OpenAPI document endpoint
    app.MapOpenApi();

    // Configure Scalar UI (development and staging only)
    if (app.Environment.IsDevelopment() || app.Environment.IsStaging())
    {
        app.MapScalarApiReference("{apiVersion}", options =>
        {
            options
                .WithTitle("{apiTitle}")
                .WithTheme(ScalarTheme.BluePlanet)
                .WithDarkModeToggle(true)
                .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient)
                .WithOAuth2BearerToken(oauth =>
                {
                    oauth.Scopes = ["{apiScope}"];
                })
                .WithPreferredScheme("OAuth2")
                .WithHttpBearerAuthentication(bearer =>
                {
                    bearer.Token = string.Empty;
                });
        });
    }

### Alternative: Simpler Scalar Configuration (No OAuth2 interactive login):

If the API uses only Bearer tokens (no interactive OAuth2 login through Scalar):

    if (app.Environment.IsDevelopment())
    {
        app.MapScalarApiReference(options =>
        {
            options
                .WithTitle("{apiTitle}")
                .WithTheme(ScalarTheme.BluePlanet)
                .WithDarkModeToggle(true);
        });
    }

## Step 5 — Configure appsettings.json

Add or update the Azure Entra ID configuration in `appsettings.json`.

### Rules:

- NEVER put real Client Secrets in appsettings.json
- Use placeholder values that will be replaced by Azure Key Vault or CI/CD
- Use User Secrets for local development

### appsettings.json Structure:

    {
      "AzureAd": {
        "Instance": "https://login.microsoftonline.com/",
        "TenantId": "{tenantId}",
        "ClientId": "{clientId}",
        "Audience": "api://{clientId}",
        "Scopes": "{apiScope}"
      },
      "Scalar": {
        "Title": "{apiTitle}",
        "RoutePrefix": "scalar"
      }
    }

### appsettings.Development.json:

    {
      "AzureAd": {
        "Instance": "https://login.microsoftonline.com/",
        "TenantId": "{tenantId}",
        "ClientId": "{clientId}",
        "Audience": "api://{clientId}"
      }
    }

### For Local Development (User Secrets):

    dotnet user-secrets init --project src/MyApp.Api
    dotnet user-secrets set "AzureAd:ClientSecret" "your-dev-secret" --project src/MyApp.Api

## Step 6 — Configure Authentication in Program.cs

Ensure the API project has proper Azure Entra ID authentication configured.

### Required Authentication Setup:

    using Microsoft.Identity.Web;

    // Authentication
    builder.Services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

    // Authorization
    builder.Services.AddAuthorization();

### Middleware Order (Critical — order matters!):

    var app = builder.Build();

    // 1. Exception handling
    app.UseExceptionHandler("/error");

    // 2. HTTPS redirection
    app.UseHttpsRedirection();

    // 3. CORS (before auth)
    app.UseCors();

    // 4. Authentication (before authorization)
    app.UseAuthentication();

    // 5. Authorization
    app.UseAuthorization();

    // 6. Rate limiting
    app.UseRateLimiter();

    // 7. Map endpoints
    app.MapControllers();

    // 8. OpenAPI and Scalar (dev/staging only)
    app.MapOpenApi();
    if (app.Environment.IsDevelopment() || app.Environment.IsStaging())
    {
        app.MapScalarApiReference("{apiVersion}", options => { /* ... */ });
    }

    // 9. Health checks
    app.MapHealthChecks("/health");
    app.MapHealthChecks("/ready");

    app.Run();

## Step 7 — Add OpenAPI Annotations to Controllers/Endpoints

Ensure all controllers and endpoints have proper OpenAPI annotations.

### Rules:

- Every action MUST have `[ProducesResponseType]` for all possible status codes
- Use `[Tags]` to group endpoints logically in Scalar
- Use `[EndpointSummary]` and `[EndpointDescription]` for Minimal APIs
- Include XML documentation comments for rich Scalar descriptions

### Controller Example with Full Annotations:

    /// <summary>
    /// Manages product resources.
    /// </summary>
    [ApiController]
    [Route("api/v1/[controller]")]
    [Produces("application/json")]
    [Authorize]
    [Tags("Products")]
    public sealed class ProductsController(
        IProductService productService,
        ILogger<ProductsController> logger) : ControllerBase
    {
        /// <summary>
        /// Retrieves all products with optional pagination.
        /// </summary>
        /// <param name="page">Page number (1-based)</param>
        /// <param name="pageSize">Number of items per page (max 100)</param>
        /// <returns>A paginated list of products</returns>
        [HttpGet]
        [ProducesResponseType(typeof(PaginatedResponse<ProductResponse>), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            var result = await productService.GetAllAsync(page, pageSize);
            return Ok(result);
        }

        /// <summary>
        /// Retrieves a single product by its unique identifier.
        /// </summary>
        /// <param name="id">The product's unique identifier</param>
        [HttpGet("{id:guid}")]
        [ProducesResponseType(typeof(ProductResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetById(Guid id)
        {
            var result = await productService.GetByIdAsync(id);
            return result is null ? NotFound() : Ok(result);
        }

        /// <summary>
        /// Creates a new product.
        /// </summary>
        /// <param name="request">The product creation request</param>
        [HttpPost]
        [ProducesResponseType(typeof(ProductResponse), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> Create([FromBody] CreateProductRequest request)
        {
            var result = await productService.CreateAsync(request);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }
    }

### Minimal API Example with Full Annotations:

    var products = app.MapGroup("/api/v1/products")
        .WithTags("Products")
        .RequireAuthorization();

    products.MapGet("/", async (
        [FromQuery] int page,
        [FromQuery] int pageSize,
        IProductService service) =>
    {
        var result = await service.GetAllAsync(page, pageSize);
        return Results.Ok(result);
    })
    .WithName("GetAllProducts")
    .WithSummary("Retrieves all products with pagination")
    .WithDescription("Returns a paginated list of products sorted by creation date")
    .Produces<PaginatedResponse<ProductResponse>>(StatusCodes.Status200OK)
    .Produces<ProblemDetails>(StatusCodes.Status401Unauthorized);

## Step 8 — Configure CORS for Scalar and Frontend

Ensure CORS is properly configured to allow Scalar UI and frontend applications.

### Rules:

- NEVER use wildcard origins in production
- Explicitly list allowed origins per environment
- Allow credentials for OAuth2 flows

### CORS Configuration:

    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(policy =>
        {
            policy
                .WithOrigins(
                    builder.Configuration.GetSection("AllowedOrigins").Get<string[]>()
                    ?? ["https://localhost:4200"])
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowCredentials();
        });
    });

### appsettings.json CORS Configuration:

    {
      "AllowedOrigins": [
        "https://localhost:4200",
        "https://localhost:3000"
      ]
    }

### appsettings.Production.json:

    {
      "AllowedOrigins": [
        "https://frontend.yourdomain.com"
      ]
    }

## Step 9 — Verify the Configuration

After completing all steps, verify the Scalar integration works correctly.

### Verification Checklist:

1. **Start the API locally**:

   dotnet run --project src/MyApp.Api

2. **Open Scalar UI** in browser:

   https://localhost:{port}/scalar/v1

3. **Verify these elements in Scalar**:
   - API title and version display correctly
   - All endpoints are visible and grouped by tags
   - OAuth2 security scheme is listed
   - Click "Authorize" and verify the Entra ID login popup appears
   - After login, verify the Bearer token is automatically included in requests
   - Test a GET endpoint to confirm it returns data

4. **Verify OpenAPI document** is accessible:

   https://localhost:{port}/openapi/v1.json

5. **Verify authentication flow**:
   - Unauthenticated request returns 401
   - After OAuth2 login, request returns 200 with data
   - Token expiry is handled gracefully

6. **Verify in different environments**:
   - Development: Scalar UI is accessible
   - Staging: Scalar UI is accessible
   - Production: Scalar UI is NOT accessible (unless explicitly enabled)

## Reminders

- Scalar replaces Swagger UI — do NOT include both in the same project
- Remove Swashbuckle.AspNetCore package if it was previously installed
- NEVER expose Scalar UI in production unless there is an explicit business requirement
- All endpoints MUST have ProducesResponseType attributes for accurate documentation
- Use XML documentation comments for rich descriptions in Scalar
- OAuth2 configuration in Scalar MUST match the Entra ID App Registration settings
- Client Secret should NEVER be configured in Scalar — use Authorization Code with PKCE
- Middleware order is critical — Authentication MUST come before Authorization
- CORS MUST be configured before Authentication in the middleware pipeline
- Rate limiting should be applied after authorization
- Test the full OAuth2 flow end-to-end before deploying to shared environments
- Use dotnet user-secrets for local development secrets, Azure Key Vault for deployed environments
