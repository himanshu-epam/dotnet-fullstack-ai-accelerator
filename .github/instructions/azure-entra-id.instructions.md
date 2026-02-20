---
applyTo: "**/*Auth*.cs,**/*Identity*.cs,**/*Token*.cs,**/Program.cs,**/*Claims*.cs,**/*Authorization*.cs,**/appsettings*.json,**/*auth*.ts,**/*msal*.ts,**/*guard*.ts,**/*interceptor*.ts,**/environment*.ts"
---

# Azure Entra ID Authentication Instructions

## Overview

ALL applications MUST use Azure Entra ID (formerly Azure AD) for authentication.
This covers BOTH backend API authentication AND frontend SPA authentication.
NEVER implement custom authentication. NEVER store passwords. NEVER build custom login pages.

## Authentication Flows

| Scenario                    | Flow                         | Library                |
| --------------------------- | ---------------------------- | ---------------------- |
| Angular / React SPA         | Authorization Code with PKCE | MSAL.js                |
| API Bearer Token Validation | JWT Bearer                   | Microsoft.Identity.Web |
| Service-to-Service          | Client Credentials           | Microsoft.Identity.Web |

NEVER use Implicit flow. ALWAYS use Authorization Code with PKCE for SPAs.

## NuGet Packages (Backend)

- Microsoft.Identity.Web
- Microsoft.Identity.Web.UI (only if the API hosts a UI)
- Microsoft.Identity.Web.MicrosoftGraph (only if calling Graph API)
- Microsoft.Identity.Web.DownstreamApi (only if calling downstream APIs)

## NPM Packages (Frontend)

Angular:

- @azure/msal-browser
- @azure/msal-angular

React:

- @azure/msal-browser
- @azure/msal-react

---

## Backend API Authentication

### appsettings.json Structure

NEVER put actual values for TenantId or ClientId in appsettings.json committed to source control.
Use placeholders and override with User Secrets (local) or Azure Key Vault (deployed).

    {
      "AzureAd": {
        "Instance": "https://login.microsoftonline.com/",
        "TenantId": "<OVERRIDE_WITH_USER_SECRETS_OR_KEYVAULT>",
        "ClientId": "<OVERRIDE_WITH_USER_SECRETS_OR_KEYVAULT>",
        "Audience": "api://<CLIENT_ID>"
      }
    }

### Program.cs Authentication Setup

    // ─── Authentication ───
    builder.Services
        .AddMicrosoftIdentityWebApiAuthentication(builder.Configuration, "AzureAd");

    // ─── Authorization with Policies ───
    builder.Services.AddAuthorizationBuilder()
        .AddPolicy("RequireAdmin", policy =>
            policy.RequireRole("Admin"))
        .AddPolicy("RequireUser", policy =>
            policy.RequireRole("User", "Admin"))
        .AddPolicy("RequireReadAccess", policy =>
            policy.RequireRole("User", "Admin", "Reader"))
        .SetDefaultPolicy(new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .Build());

    // ─── Middleware (ORDER MATTERS) ───
    app.UseAuthentication();   // Must come before UseAuthorization
    app.UseAuthorization();    // Must come after UseAuthentication

### Controller Authorization Patterns

    [ApiController]
    [Route("api/v1/[controller]")]
    [Authorize]
    public sealed class UsersController(
        IUserService userService,
        ILogger<UsersController> logger) : ControllerBase
    {
        [HttpGet]
        [Authorize(Policy = "RequireReadAccess")]
        public async Task<IActionResult> GetAll(
            CancellationToken cancellationToken = default)
        {
            // Users with Reader, User, or Admin role can access
        }

        [HttpPost]
        [Authorize(Policy = "RequireUser")]
        public async Task<IActionResult> Create(
            [FromBody] CreateUserRequest request,
            CancellationToken cancellationToken = default)
        {
            // Only Users and Admins can create
        }

        [HttpDelete("{id:guid}")]
        [Authorize(Policy = "RequireAdmin")]
        public async Task<IActionResult> Delete(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            // Only Admins can delete
        }

        [HttpGet("health")]
        [AllowAnonymous]
        public IActionResult Health() => Ok(new { status = "healthy" });
    }

---

## Extracting User Information from Claims

Create a reusable extension class for extracting user info from the JWT token:

    public static class ClaimsPrincipalExtensions
    {
        public static Guid GetUserId(this ClaimsPrincipal user)
        {
            var objectId = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/objectidentifier")
                ?? user.FindFirstValue("oid")
                ?? throw new UnauthorizedAccessException("User Object ID claim not found in token.");

            return Guid.Parse(objectId);
        }

        public static string GetEmail(this ClaimsPrincipal user)
        {
            return user.FindFirstValue("preferred_username")
                ?? user.FindFirstValue(ClaimTypes.Email)
                ?? user.FindFirstValue("email")
                ?? throw new UnauthorizedAccessException("Email claim not found in token.");
        }

        public static string GetDisplayName(this ClaimsPrincipal user)
        {
            return user.FindFirstValue("name")
                ?? user.FindFirstValue(ClaimTypes.Name)
                ?? "Unknown User";
        }

        public static IReadOnlyList<string> GetRoles(this ClaimsPrincipal user)
        {
            return user.FindAll(ClaimTypes.Role)
                .Select(c => c.Value)
                .ToList();
        }

        public static bool HasRole(this ClaimsPrincipal user, string role)
        {
            return user.IsInRole(role);
        }

        public static Guid GetTenantId(this ClaimsPrincipal user)
        {
            var tenantId = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/tenantid")
                ?? user.FindFirstValue("tid")
                ?? throw new UnauthorizedAccessException("Tenant ID claim not found in token.");

            return Guid.Parse(tenantId);
        }
    }

### Usage in Controllers

    [HttpPost]
    [Authorize(Policy = "RequireUser")]
    public async Task<IActionResult> Create(
        [FromBody] CreateProjectRequest request,
        CancellationToken cancellationToken = default)
    {
        var userId = User.GetUserId();
        var userEmail = User.GetEmail();

        logger.LogInformation(
            "User {UserId} ({Email}) creating project {ProjectName}",
            userId, userEmail, request.Name);

        var result = await projectService.CreateAsync(userId, request, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

---

## Angular MSAL Integration

### Environment Configuration

    // environments/environment.ts
    export const environment = {
      production: false,
      apiBaseUrl: 'https://localhost:7001',
      azure: {
        clientId: '<CLIENT_ID>',
        tenantId: '<TENANT_ID>',
        redirectUri: 'http://localhost:4200',
        postLogoutRedirectUri: 'http://localhost:4200',
        apiScope: 'api://<API_CLIENT_ID>/access_as_user'
      }
    };

    // environments/environment.prod.ts
    export const environment = {
      production: true,
      apiBaseUrl: '__API_BASE_URL__',
      azure: {
        clientId: '__AZURE_CLIENT_ID__',
        tenantId: '__AZURE_TENANT_ID__',
        redirectUri: '__REDIRECT_URI__',
        postLogoutRedirectUri: '__POST_LOGOUT_REDIRECT_URI__',
        apiScope: '__API_SCOPE__'
      }
    };

Use placeholder tokens (prefixed and suffixed with \_\_) in production environment files.
These are replaced during CI/CD pipeline deployment.

### MSAL Configuration

    // config/msal.config.ts
    import {
      MsalGuardConfiguration,
      MsalInterceptorConfiguration
    } from '@azure/msal-angular';
    import {
      BrowserCacheLocation,
      InteractionType,
      LogLevel,
      PublicClientApplication
    } from '@azure/msal-browser';
    import { environment } from '@environments/environment';

    export function msalInstanceFactory(): PublicClientApplication {
      return new PublicClientApplication({
        auth: {
          clientId: environment.azure.clientId,
          authority: `https://login.microsoftonline.com/${environment.azure.tenantId}`,
          redirectUri: environment.azure.redirectUri,
          postLogoutRedirectUri: environment.azure.postLogoutRedirectUri
        },
        cache: {
          cacheLocation: BrowserCacheLocation.LocalStorage,
          storeAuthStateInCookie: false
        },
        system: {
          loggerOptions: {
            logLevel: environment.production ? LogLevel.Error : LogLevel.Warning,
            piiLoggingEnabled: false
          }
        }
      });
    }

    export function msalGuardConfigFactory(): MsalGuardConfiguration {
      return {
        interactionType: InteractionType.Redirect,
        authRequest: {
          scopes: [environment.azure.apiScope]
        },
        loginFailedRoute: '/login-failed'
      };
    }

    export function msalInterceptorConfigFactory(): MsalInterceptorConfiguration {
      const protectedResourceMap = new Map<string, string[]>();

      // Protect all API calls with the API scope
      protectedResourceMap.set(
        `${environment.apiBaseUrl}/*`,
        [environment.azure.apiScope]
      );

      return {
        interactionType: InteractionType.Redirect,
        protectedResourceMap
      };
    }

### App Configuration (app.config.ts)

    // app.config.ts
    import { ApplicationConfig, importProvidersFrom } from '@angular/core';
    import { provideRouter } from '@angular/router';
    import { provideHttpClient, withInterceptorsFromDi } from '@angular/common/http';
    import {
      MSAL_GUARD_CONFIG,
      MSAL_INSTANCE,
      MSAL_INTERCEPTOR_CONFIG,
      MsalBroadcastService,
      MsalGuard,
      MsalInterceptor,
      MsalService
    } from '@azure/msal-angular';
    import { HTTP_INTERCEPTORS } from '@angular/common/http';
    import {
      msalInstanceFactory,
      msalGuardConfigFactory,
      msalInterceptorConfigFactory
    } from '@app/config/msal.config';
    import { routes } from './app.routes';

    export const appConfig: ApplicationConfig = {
      providers: [
        provideRouter(routes),
        provideHttpClient(withInterceptorsFromDi()),
        {
          provide: MSAL_INSTANCE,
          useFactory: msalInstanceFactory
        },
        {
          provide: MSAL_GUARD_CONFIG,
          useFactory: msalGuardConfigFactory
        },
        {
          provide: MSAL_INTERCEPTOR_CONFIG,
          useFactory: msalInterceptorConfigFactory
        },
        {
          provide: HTTP_INTERCEPTORS,
          useClass: MsalInterceptor,
          multi: true
        },
        MsalService,
        MsalGuard,
        MsalBroadcastService
      ]
    };

### App Component with MSAL Initialization

    // app.component.ts
    import { Component, OnInit, OnDestroy, inject } from '@angular/core';
    import { RouterOutlet } from '@angular/router';
    import { MsalBroadcastService, MsalService } from '@azure/msal-angular';
    import { InteractionStatus } from '@azure/msal-browser';
    import { Subject, filter, takeUntil } from 'rxjs';

    @Component({
      selector: 'app-root',
      standalone: true,
      imports: [RouterOutlet],
      template: '<router-outlet />'
    })
    export class AppComponent implements OnInit, OnDestroy {
      private readonly msalService = inject(MsalService);
      private readonly broadcastService = inject(MsalBroadcastService);
      private readonly destroying$ = new Subject<void>();

      ngOnInit(): void {
        this.msalService.handleRedirectObservable().subscribe();

        this.broadcastService.inProgress$
          .pipe(
            filter((status) => status === InteractionStatus.None),
            takeUntil(this.destroying$)
          )
          .subscribe(() => {
            this.checkAndSetActiveAccount();
          });
      }

      private checkAndSetActiveAccount(): void {
        const activeAccount = this.msalService.instance.getActiveAccount();
        if (!activeAccount && this.msalService.instance.getAllAccounts().length > 0) {
          const accounts = this.msalService.instance.getAllAccounts();
          this.msalService.instance.setActiveAccount(accounts[0]);
        }
      }

      ngOnDestroy(): void {
        this.destroying$.next();
        this.destroying$.complete();
      }
    }

### Routes with MsalGuard

    // app.routes.ts
    import { Routes } from '@angular/router';
    import { MsalGuard } from '@azure/msal-angular';

    export const routes: Routes = [
      {
        path: '',
        redirectTo: 'users',
        pathMatch: 'full'
      },
      {
        path: 'users',
        canActivate: [MsalGuard],
        loadComponent: () =>
          import('./features/users/user-list/user-list.component')
            .then(m => m.UserListComponent)
      },
      {
        path: 'users/:id',
        canActivate: [MsalGuard],
        loadComponent: () =>
          import('./features/users/user-detail/user-detail.component')
            .then(m => m.UserDetailComponent)
      },
      {
        path: 'login-failed',
        loadComponent: () =>
          import('./shared/components/login-failed/login-failed.component')
            .then(m => m.LoginFailedComponent)
      }
    ];

### Auth Service for User Info

    // services/auth.service.ts
    import { Injectable, inject, signal, computed } from '@angular/core';
    import { MsalService } from '@azure/msal-angular';
    import { AccountInfo } from '@azure/msal-browser';
    import { environment } from '@environments/environment';

    export interface AuthUser {
      id: string;
      email: string;
      displayName: string;
      roles: string[];
    }

    @Injectable({ providedIn: 'root' })
    export class AuthService {
      private readonly msalService = inject(MsalService);

      private readonly activeAccount = signal<AccountInfo | null>(
        this.msalService.instance.getActiveAccount()
      );

      readonly isAuthenticated = computed(() => this.activeAccount() !== null);

      readonly currentUser = computed<AuthUser | null>(() => {
        const account = this.activeAccount();
        if (!account) return null;

        return {
          id: account.localAccountId,
          email: account.username,
          displayName: account.name ?? account.username,
          roles: (account.idTokenClaims?.['roles'] as string[]) ?? []
        };
      });

      readonly hasAdminRole = computed(() =>
        this.currentUser()?.roles.includes('Admin') ?? false
      );

      login(): void {
        this.msalService.loginRedirect({
          scopes: [environment.azure.apiScope]
        });
      }

      logout(): void {
        this.msalService.logoutRedirect({
          postLogoutRedirectUri: environment.azure.postLogoutRedirectUri
        });
      }

      refreshAccount(): void {
        const account = this.msalService.instance.getActiveAccount();
        this.activeAccount.set(account);
      }

      hasRole(role: string): boolean {
        return this.currentUser()?.roles.includes(role) ?? false;
      }
    }

### Using Auth in Components

    // header.component.ts
    @Component({
      selector: 'app-header',
      standalone: true,
      imports: [CommonModule],
      changeDetection: ChangeDetectionStrategy.OnPush,
      template: `
        <header>
          @if (authService.isAuthenticated()) {
            <span>Welcome, {{ authService.currentUser()?.displayName }}</span>
            <button (click)="authService.logout()">Sign Out</button>
          }
        </header>
      `
    })
    export class HeaderComponent {
      protected readonly authService = inject(AuthService);
    }

---

## React MSAL Integration

### Environment Configuration

    // .env.development
    VITE_API_BASE_URL=https://localhost:7001
    VITE_AZURE_CLIENT_ID=<CLIENT_ID>
    VITE_AZURE_TENANT_ID=<TENANT_ID>
    VITE_REDIRECT_URI=http://localhost:5173
    VITE_POST_LOGOUT_REDIRECT_URI=http://localhost:5173
    VITE_API_SCOPE=api://<API_CLIENT_ID>/access_as_user

    // .env.production
    VITE_API_BASE_URL=__API_BASE_URL__
    VITE_AZURE_CLIENT_ID=__AZURE_CLIENT_ID__
    VITE_AZURE_TENANT_ID=__AZURE_TENANT_ID__
    VITE_REDIRECT_URI=__REDIRECT_URI__
    VITE_POST_LOGOUT_REDIRECT_URI=__POST_LOGOUT_REDIRECT_URI__
    VITE_API_SCOPE=__API_SCOPE__

### MSAL Configuration

    // config/authConfig.ts
    import {
      Configuration,
      LogLevel,
      PublicClientApplication
    } from '@azure/msal-browser';

    const msalConfig: Configuration = {
      auth: {
        clientId: import.meta.env.VITE_AZURE_CLIENT_ID,
        authority: `https://login.microsoftonline.com/${import.meta.env.VITE_AZURE_TENANT_ID}`,
        redirectUri: import.meta.env.VITE_REDIRECT_URI,
        postLogoutRedirectUri: import.meta.env.VITE_POST_LOGOUT_REDIRECT_URI
      },
      cache: {
        cacheLocation: 'localStorage',
        storeAuthStateInCookie: false
      },
      system: {
        loggerOptions: {
          logLevel: import.meta.env.PROD ? LogLevel.Error : LogLevel.Warning,
          piiLoggingEnabled: false
        }
      }
    };

    export const msalInstance = new PublicClientApplication(msalConfig);

    export const loginRequest = {
      scopes: [import.meta.env.VITE_API_SCOPE]
    };

    export const apiTokenRequest = {
      scopes: [import.meta.env.VITE_API_SCOPE]
    };

### MSAL Initialization in main.tsx

    // main.tsx
    import { StrictMode } from 'react';
    import { createRoot } from 'react-dom/client';
    import { EventType } from '@azure/msal-browser';
    import { msalInstance } from '@/config/authConfig';
    import { App } from './App';

    // Handle redirect promise and set active account
    msalInstance.initialize().then(() => {
      const accounts = msalInstance.getAllAccounts();
      if (accounts.length > 0) {
        msalInstance.setActiveAccount(accounts[0]);
      }

      msalInstance.addEventCallback((event) => {
        if (event.eventType === EventType.LOGIN_SUCCESS && event.payload) {
          const account = (event.payload as { account: any }).account;
          msalInstance.setActiveAccount(account);
        }
      });

      msalInstance.handleRedirectPromise().then(() => {
        createRoot(document.getElementById('root')!).render(
          <StrictMode>
            <App />
          </StrictMode>
        );
      });
    });

### App Component with MSAL Provider

    // App.tsx
    import { FC, lazy, Suspense } from 'react';
    import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
    import { MsalProvider } from '@azure/msal-react';
    import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
    import { msalInstance } from '@/config/authConfig';
    import { AuthGuard } from '@/components/auth/AuthGuard';
    import { Layout } from '@/components/layout/Layout';
    import { Spinner } from '@/components/ui/Spinner';

    const UserList = lazy(() =>
      import('@/features/users/UserList').then(m => ({ default: m.UserList }))
    );
    const UserDetail = lazy(() =>
      import('@/features/users/UserDetail').then(m => ({ default: m.UserDetail }))
    );
    const LoginFailed = lazy(() =>
      import('@/components/shared/LoginFailed').then(m => ({ default: m.LoginFailed }))
    );

    const queryClient = new QueryClient({
      defaultOptions: {
        queries: {
          staleTime: 5 * 60 * 1000,
          retry: 1,
          refetchOnWindowFocus: false
        }
      }
    });

    export const App: FC = () => {
      return (
        <MsalProvider instance={msalInstance}>
          <QueryClientProvider client={queryClient}>
            <BrowserRouter>
              <Suspense fallback={<Spinner />}>
                <Routes>
                  <Route path="/login-failed" element={<LoginFailed />} />
                  <Route element={<AuthGuard><Layout /></AuthGuard>}>
                    <Route path="/" element={<Navigate to="/users" replace />} />
                    <Route path="/users" element={<UserList />} />
                    <Route path="/users/:id" element={<UserDetail />} />
                  </Route>
                </Routes>
              </Suspense>
            </BrowserRouter>
          </QueryClientProvider>
        </MsalProvider>
      );
    };

### Auth Guard Component

    // components/auth/AuthGuard.tsx
    import { FC, ReactNode, useEffect } from 'react';
    import {
      useMsal,
      useIsAuthenticated,
      MsalAuthenticationTemplate,
      UnauthenticatedTemplate
    } from '@azure/msal-react';
    import { InteractionType } from '@azure/msal-browser';
    import { loginRequest } from '@/config/authConfig';
    import { Spinner } from '@/components/ui/Spinner';

    interface AuthGuardProps {
      children: ReactNode;
    }

    export const AuthGuard: FC<AuthGuardProps> = ({ children }) => {
      return (
        <MsalAuthenticationTemplate
          interactionType={InteractionType.Redirect}
          authenticationRequest={loginRequest}
          loadingComponent={Spinner}
          errorComponent={AuthError}
        >
          {children}
        </MsalAuthenticationTemplate>
      );
    };

    const AuthError: FC<{ error: any }> = ({ error }) => {
      return (
        <div role="alert">
          <h2>Authentication Error</h2>
          <p>An error occurred during sign-in. Please try again.</p>
          <pre>{error?.message}</pre>
        </div>
      );
    };

### Auth Hook for User Info

    // hooks/useAuth.ts
    import { useMemo } from 'react';
    import { useMsal, useIsAuthenticated } from '@azure/msal-react';
    import { loginRequest } from '@/config/authConfig';

    export interface AuthUser {
      id: string;
      email: string;
      displayName: string;
      roles: string[];
    }

    export const useAuth = () => {
      const { instance, accounts } = useMsal();
      const isAuthenticated = useIsAuthenticated();

      const currentUser = useMemo<AuthUser | null>(() => {
        if (!isAuthenticated || accounts.length === 0) return null;

        const account = accounts[0];
        return {
          id: account.localAccountId,
          email: account.username,
          displayName: account.name ?? account.username,
          roles: (account.idTokenClaims?.['roles'] as string[]) ?? []
        };
      }, [isAuthenticated, accounts]);

      const hasRole = (role: string): boolean => {
        return currentUser?.roles.includes(role) ?? false;
      };

      const login = (): void => {
        instance.loginRedirect(loginRequest);
      };

      const logout = (): void => {
        instance.logoutRedirect({
          postLogoutRedirectUri: import.meta.env.VITE_POST_LOGOUT_REDIRECT_URI
        });
      };

      return {
        isAuthenticated,
        currentUser,
        hasRole,
        login,
        logout
      };
    };

### API Client with Token Injection

    // lib/apiClient.ts
    import axios from 'axios';
    import { msalInstance, apiTokenRequest } from '@/config/authConfig';

    const apiClient = axios.create({
      baseURL: import.meta.env.VITE_API_BASE_URL,
      headers: { 'Content-Type': 'application/json' }
    });

    apiClient.interceptors.request.use(async (config) => {
      const account = msalInstance.getActiveAccount();
      if (account) {
        try {
          const response = await msalInstance.acquireTokenSilent({
            ...apiTokenRequest,
            account
          });
          config.headers.Authorization = `Bearer ${response.accessToken}`;
        } catch (error) {
          // Silent token acquisition failed — trigger redirect login
          await msalInstance.acquireTokenRedirect(apiTokenRequest);
        }
      }
      return config;
    });

    apiClient.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          await msalInstance.acquireTokenRedirect(apiTokenRequest);
        }
        return Promise.reject(error);
      }
    );

    export { apiClient };

### Using Auth in Components

    // components/layout/Header.tsx
    import { FC } from 'react';
    import { useAuth } from '@/hooks/useAuth';

    export const Header: FC = () => {
      const { isAuthenticated, currentUser, hasRole, logout } = useAuth();

      return (
        <header>
          {isAuthenticated && currentUser && (
            <>
              <span>Welcome, {currentUser.displayName}</span>
              {hasRole('Admin') && <span className="badge">Admin</span>}
              <button onClick={logout}>Sign Out</button>
            </>
          )}
        </header>
      );
    };

### Role-Based UI Rendering

    // components/auth/RequireRole.tsx
    import { FC, ReactNode } from 'react';
    import { useAuth } from '@/hooks/useAuth';

    interface RequireRoleProps {
      role: string;
      children: ReactNode;
      fallback?: ReactNode;
    }

    export const RequireRole: FC<RequireRoleProps> = ({ role, children, fallback = null }) => {
      const { hasRole } = useAuth();

      if (!hasRole(role)) {
        return <>{fallback}</>;
      }

      return <>{children}</>;
    };

    // Usage
    <RequireRole role="Admin">
      <button onClick={() => deleteUser(id)}>Delete User</button>
    </RequireRole>

---

## Service-to-Service Authentication (Client Credentials Flow)

When your API needs to call another API:

### appsettings.json

    {
      "DownstreamApi": {
        "BaseUrl": "https://other-api.example.com",
        "Scopes": ["api://<OTHER_API_CLIENT_ID>/.default"]
      }
    }

### Registration

    builder.Services
        .AddMicrosoftIdentityWebApiAuthentication(builder.Configuration)
        .EnableTokenAcquisitionToCallDownstreamApi()
        .AddDownstreamApi("OtherApi", builder.Configuration.GetSection("DownstreamApi"))
        .AddInMemoryTokenCaches();

### Usage

    public sealed class ExternalApiService(
        IDownstreamApi downstreamApi,
        ILogger<ExternalApiService> logger) : IExternalApiService
    {
        public async Task<ExternalData?> GetDataAsync(
            string resourceId, CancellationToken cancellationToken = default)
        {
            try
            {
                return await downstreamApi.GetForUserAsync<ExternalData>(
                    "OtherApi",
                    options => options.RelativePath = $"api/v1/data/{resourceId}",
                    cancellationToken: cancellationToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to call external API for {ResourceId}", resourceId);
                return null;
            }
        }
    }

---

## Secrets Management

### Local Development — User Secrets (Backend)

    dotnet user-secrets init --project src/MyApp.Api
    dotnet user-secrets set "AzureAd:TenantId" "<your-tenant-id>" --project src/MyApp.Api
    dotnet user-secrets set "AzureAd:ClientId" "<your-client-id>" --project src/MyApp.Api

### Local Development — .env Files (Frontend)

Use .env.development for local settings. NEVER commit .env files with real values.
Add .env.local and .env.development.local to .gitignore.

### Deployed Environments — Azure Key Vault (Backend)

    if (!builder.Environment.IsDevelopment())
    {
        var keyVaultUri = new Uri(builder.Configuration["KeyVault:Uri"]!);
        builder.Configuration.AddAzureKeyVault(keyVaultUri, new DefaultAzureCredential());
    }

Key Vault secret naming: AzureAd--TenantId maps to AzureAd:TenantId

### Deployed Environments — Token Replacement (Frontend)

Use placeholder tokens in environment.prod.ts and .env.production:

    __AZURE_CLIENT_ID__    → replaced during CI/CD pipeline
    __AZURE_TENANT_ID__    → replaced during CI/CD pipeline
    __API_SCOPE__          → replaced during CI/CD pipeline

Replace tokens in the Azure DevOps pipeline using a Replace Tokens task
or a script step before building the frontend.

---

## Testing with Authentication

### Backend — Integration Test Auth Bypass

    public sealed class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        public const string SchemeName = "TestScheme";
        public const string DefaultUserId = "00000000-0000-0000-0000-000000000001";
        public const string DefaultEmail = "test@example.com";

        public TestAuthHandler(
            IOptionsMonitor<AuthenticationSchemeOptions> options,
            ILoggerFactory logger,
            UrlEncoder encoder) : base(options, logger, encoder) { }

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var claims = new[]
            {
                new Claim("oid", DefaultUserId),
                new Claim("preferred_username", DefaultEmail),
                new Claim("name", "Test User"),
                new Claim(ClaimTypes.Role, "User"),
                new Claim(ClaimTypes.Role, "Admin"),
            };

            var identity = new ClaimsIdentity(claims, SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);

            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }

### Using Test Auth in Integration Tests

    _client = factory.WithWebHostBuilder(builder =>
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });
        });
    }).CreateClient();

### Frontend — Mocking MSAL in Tests

Angular test setup:

    // Mock MsalService in component tests
    const msalServiceMock = {
      instance: {
        getActiveAccount: jest.fn().mockReturnValue({
          localAccountId: '00000000-0000-0000-0000-000000000001',
          username: 'test@example.com',
          name: 'Test User',
          idTokenClaims: { roles: ['User', 'Admin'] }
        }),
        getAllAccounts: jest.fn().mockReturnValue([]),
        setActiveAccount: jest.fn()
      },
      handleRedirectObservable: jest.fn().mockReturnValue(of(null)),
      loginRedirect: jest.fn(),
      logoutRedirect: jest.fn()
    };

    await TestBed.configureTestingModule({
      imports: [ComponentUnderTest],
      providers: [
        { provide: MsalService, useValue: msalServiceMock },
        { provide: MsalBroadcastService, useValue: { inProgress$: of(InteractionStatus.None) } }
      ]
    }).compileComponents();

React test setup:

    // Mock useAuth hook in component tests
    vi.mock('@/hooks/useAuth', () => ({
      useAuth: () => ({
        isAuthenticated: true,
        currentUser: {
          id: '00000000-0000-0000-0000-000000000001',
          email: 'test@example.com',
          displayName: 'Test User',
          roles: ['User', 'Admin']
        },
        hasRole: (role: string) => ['User', 'Admin'].includes(role),
        login: vi.fn(),
        logout: vi.fn()
      })
    }));

---

## Rules Summary

### Backend Authentication Rules

1. ALWAYS use Azure Entra ID — NEVER implement custom authentication
2. ALWAYS use Microsoft.Identity.Web for API authentication
3. ALWAYS configure authentication BEFORE authorization in middleware pipeline
4. ALWAYS use [Authorize] at controller level as default
5. ALWAYS use [AllowAnonymous] explicitly and sparingly
6. ALWAYS define authorization policies for different access levels
7. ALWAYS create ClaimsPrincipalExtensions for extracting user info
8. ALWAYS use the `oid` claim for user identification (not `sub` or `email`)

### Angular Authentication Rules

9. ALWAYS use @azure/msal-angular for authentication
10. ALWAYS use MsalInterceptor to inject tokens into API calls automatically
11. ALWAYS use MsalGuard on protected routes
12. ALWAYS use InteractionType.Redirect (not Popup) for enterprise apps
13. ALWAYS create an AuthService with signals for reactive user state
14. ALWAYS handle redirect observable in AppComponent ngOnInit
15. ALWAYS set active account after login

### React Authentication Rules

16. ALWAYS use @azure/msal-react for authentication
17. ALWAYS wrap App with MsalProvider
18. ALWAYS use MsalAuthenticationTemplate for route protection
19. ALWAYS initialize MSAL and handle redirect promise before rendering
20. ALWAYS create a useAuth hook for user info and role checking
21. ALWAYS use acquireTokenSilent in API interceptor with redirect fallback
22. ALWAYS create a RequireRole component for role-based UI rendering

### Secrets Rules

23. NEVER store TenantId, ClientId, or secrets in source-controlled config files
24. ALWAYS use User Secrets (backend) and .env.local (frontend) for local development
25. ALWAYS use Azure Key Vault for backend secrets in deployed environments
26. ALWAYS use token replacement for frontend config in CI/CD pipelines
27. ALWAYS add .env.local and .env.\*.local to .gitignore

### Testing Rules

28. ALWAYS create TestAuthHandler for backend integration tests
29. ALWAYS mock MsalService (Angular) or useAuth hook (React) in frontend tests
30. NEVER call real Entra ID endpoints in tests
31. ALWAYS test authenticated, unauthorized, and role-based scenarios

### Flow Rules

32. SPAs: Authorization Code with PKCE — NEVER use Implicit flow
33. Service-to-Service: Client Credentials flow
34. API: JWT Bearer validation
