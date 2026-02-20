---
applyTo: "**/*.tsx,**/*.jsx,**/vite.config.*,**/next.config.*,**/*.hook.ts,**/*.hook.tsx"
---

# React Development Instructions

## Component Pattern

All components MUST use functional components with TypeScript:

    // UserList.tsx
    import { FC } from 'react';
    import { useQuery } from '@tanstack/react-query';
    import { userApi } from '@/services/userApi';
    import { Spinner } from '@/components/ui/Spinner';
    import { ErrorBanner } from '@/components/ui/ErrorBanner';
    import { UserCard } from './UserCard';

    interface UserListProps {
      teamId?: string;
    }

    export const UserList: FC<UserListProps> = ({ teamId }) => {
      const {
        data: users,
        isLoading,
        error,
        refetch
      } = useQuery({
        queryKey: ['users', teamId],
        queryFn: () => teamId
          ? userApi.getByTeam(teamId)
          : userApi.getAll(),
      });

      if (isLoading) {
        return <Spinner />;
      }

      if (error) {
        return (
          <ErrorBanner
            message="Failed to load users. Please try again."
            onRetry={refetch}
          />
        );
      }

      if (!users?.items.length) {
        return <p className="no-results">No users found.</p>;
      }

      return (
        <div className="user-list">
          <h2>Users ({users.totalCount})</h2>
          <div className="user-grid">
            {users.items.map((user) => (
              <UserCard key={user.id} user={user} />
            ))}
          </div>
        </div>
      );
    };

---

## API Service Pattern

Create a centralized API client and typed service functions:

    // lib/apiClient.ts
    import axios from 'axios';
    import { msalInstance } from '@/config/authConfig';

    const apiClient = axios.create({
      baseURL: import.meta.env.VITE_API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Auth token interceptor
    apiClient.interceptors.request.use(async (config) => {
      const accounts = msalInstance.getAllAccounts();
      if (accounts.length > 0) {
        try {
          const response = await msalInstance.acquireTokenSilent({
            scopes: [import.meta.env.VITE_API_SCOPE],
            account: accounts[0],
          });
          config.headers.Authorization = `Bearer ${response.accessToken}`;
        } catch (error) {
          console.error('Token acquisition failed:', error);
        }
      }
      return config;
    });

    // Error response interceptor
    apiClient.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          msalInstance.loginRedirect();
        }
        return Promise.reject(error);
      }
    );

    export { apiClient };

---

## Typed API Service Pattern

    // services/userApi.ts
    import { apiClient } from '@/lib/apiClient';
    import {
      User,
      CreateUserRequest,
      UpdateUserRequest,
      PagedResult
    } from '@/models/user';

    export const userApi = {
      getAll: async (page: number = 1, pageSize: number = 20): Promise<PagedResult<User>> => {
        const response = await apiClient.get<PagedResult<User>>('/api/v1/users', {
          params: { page, pageSize },
        });
        return response.data;
      },

      getById: async (id: string): Promise<User> => {
        const response = await apiClient.get<User>(`/api/v1/users/${id}`);
        return response.data;
      },

      create: async (data: CreateUserRequest): Promise<User> => {
        const response = await apiClient.post<User>('/api/v1/users', data);
        return response.data;
      },

      update: async (id: string, data: UpdateUserRequest): Promise<User> => {
        const response = await apiClient.put<User>(`/api/v1/users/${id}`, data);
        return response.data;
      },

      delete: async (id: string): Promise<void> => {
        await apiClient.delete(`/api/v1/users/${id}`);
      },
    };

---

## Model Pattern

    // models/user.ts
    export interface User {
      id: string;
      email: string;
      displayName: string;
      createdAt: string;
      updatedAt: string | null;
    }

    export interface CreateUserRequest {
      email: string;
      displayName: string;
    }

    export interface UpdateUserRequest {
      displayName: string;
    }

    export interface PagedResult<T> {
      items: T[];
      totalCount: number;
      page: number;
      pageSize: number;
      totalPages: number;
      hasNextPage: boolean;
      hasPreviousPage: boolean;
    }

---

## Custom Hook Pattern

Encapsulate reusable business logic in custom hooks:

    // hooks/useUsers.ts
    import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
    import { userApi } from '@/services/userApi';
    import { CreateUserRequest, UpdateUserRequest } from '@/models/user';

    const USERS_QUERY_KEY = ['users'] as const;

    export const useUsers = (page: number = 1, pageSize: number = 20) => {
      return useQuery({
        queryKey: [...USERS_QUERY_KEY, page, pageSize],
        queryFn: () => userApi.getAll(page, pageSize),
      });
    };

    export const useUser = (id: string) => {
      return useQuery({
        queryKey: [...USERS_QUERY_KEY, id],
        queryFn: () => userApi.getById(id),
        enabled: !!id,
      });
    };

    export const useCreateUser = () => {
      const queryClient = useQueryClient();

      return useMutation({
        mutationFn: (data: CreateUserRequest) => userApi.create(data),
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: USERS_QUERY_KEY });
        },
      });
    };

    export const useUpdateUser = () => {
      const queryClient = useQueryClient();

      return useMutation({
        mutationFn: ({ id, data }: { id: string; data: UpdateUserRequest }) =>
          userApi.update(id, data),
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: USERS_QUERY_KEY });
        },
      });
    };

    export const useDeleteUser = () => {
      const queryClient = useQueryClient();

      return useMutation({
        mutationFn: (id: string) => userApi.delete(id),
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: USERS_QUERY_KEY });
        },
      });
    };

---

## Form Pattern

Use controlled forms with proper validation and error handling:

    // features/users/UserForm.tsx
    import { FC, FormEvent, useState } from 'react';
    import { useNavigate, useParams } from 'react-router-dom';
    import { useUser, useCreateUser, useUpdateUser } from '@/hooks/useUsers';
    import { Spinner } from '@/components/ui/Spinner';
    import { ErrorBanner } from '@/components/ui/ErrorBanner';

    interface FormErrors {
      email?: string;
      displayName?: string;
    }

    export const UserForm: FC = () => {
      const { id } = useParams<{ id: string }>();
      const navigate = useNavigate();
      const isEditMode = !!id;

      const { data: existingUser, isLoading: isLoadingUser } = useUser(id ?? '');
      const createUser = useCreateUser();
      const updateUser = useUpdateUser();

      const [email, setEmail] = useState('');
      const [displayName, setDisplayName] = useState('');
      const [errors, setErrors] = useState<FormErrors>({});
      const [serverError, setServerError] = useState<string | null>(null);

      // Populate form when editing
      useState(() => {
        if (existingUser) {
          setEmail(existingUser.email);
          setDisplayName(existingUser.displayName);
        }
      });

      const validate = (): boolean => {
        const newErrors: FormErrors = {};

        if (!email.trim()) {
          newErrors.email = 'Email is required.';
        } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          newErrors.email = 'Please enter a valid email.';
        }

        if (!displayName.trim()) {
          newErrors.displayName = 'Display name is required.';
        } else if (displayName.length > 100) {
          newErrors.displayName = 'Display name must be 100 characters or less.';
        }

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
      };

      const handleSubmit = async (e: FormEvent): Promise<void> => {
        e.preventDefault();
        setServerError(null);

        if (!validate()) {
          return;
        }

        try {
          if (isEditMode && id) {
            await updateUser.mutateAsync({ id, data: { displayName } });
          } else {
            await createUser.mutateAsync({ email, displayName });
          }
          navigate('/users');
        } catch {
          setServerError('Failed to save user. Please try again.');
        }
      };

      const isSubmitting = createUser.isPending || updateUser.isPending;

      if (isEditMode && isLoadingUser) {
        return <Spinner />;
      }

      return (
        <form onSubmit={handleSubmit} noValidate>
          <h2>{isEditMode ? 'Edit' : 'Create'} User</h2>

          {serverError && <ErrorBanner message={serverError} />}

          <div className="form-field">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={isEditMode}
              aria-invalid={!!errors.email}
              aria-describedby={errors.email ? 'email-error' : undefined}
            />
            {errors.email && (
              <span id="email-error" className="error" role="alert">
                {errors.email}
              </span>
            )}
          </div>

          <div className="form-field">
            <label htmlFor="displayName">Display Name</label>
            <input
              id="displayName"
              type="text"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              aria-invalid={!!errors.displayName}
              aria-describedby={errors.displayName ? 'name-error' : undefined}
            />
            {errors.displayName && (
              <span id="name-error" className="error" role="alert">
                {errors.displayName}
              </span>
            )}
          </div>

          <button type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Saving...' : isEditMode ? 'Update User' : 'Create User'}
          </button>
        </form>
      );
    };

---

## MSAL Auth Configuration Pattern

    // config/authConfig.ts
    import { PublicClientApplication, Configuration } from '@azure/msal-browser';

    const msalConfig: Configuration = {
      auth: {
        clientId: import.meta.env.VITE_AZURE_CLIENT_ID,
        authority: `https://login.microsoftonline.com/${import.meta.env.VITE_AZURE_TENANT_ID}`,
        redirectUri: import.meta.env.VITE_REDIRECT_URI,
      },
      cache: {
        cacheLocation: 'localStorage',
        storeAuthStateInCookie: false,
      },
    };

    export const msalInstance = new PublicClientApplication(msalConfig);

    export const loginRequest = {
      scopes: [import.meta.env.VITE_API_SCOPE],
    };

---

## Auth Guard Component Pattern

    // components/auth/AuthGuard.tsx
    import { FC, ReactNode } from 'react';
    import { useMsal, useIsAuthenticated } from '@azure/msal-react';
    import { loginRequest } from '@/config/authConfig';
    import { Spinner } from '@/components/ui/Spinner';

    interface AuthGuardProps {
      children: ReactNode;
    }

    export const AuthGuard: FC<AuthGuardProps> = ({ children }) => {
      const { instance, inProgress } = useMsal();
      const isAuthenticated = useIsAuthenticated();

      if (inProgress !== 'none') {
        return <Spinner />;
      }

      if (!isAuthenticated) {
        instance.loginRedirect(loginRequest);
        return <Spinner />;
      }

      return <>{children}</>;
    };

---

## Routing Pattern

    // App.tsx
    import { FC, lazy, Suspense } from 'react';
    import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
    import { MsalProvider } from '@azure/msal-react';
    import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
    import { msalInstance } from '@/config/authConfig';
    import { AuthGuard } from '@/components/auth/AuthGuard';
    import { Spinner } from '@/components/ui/Spinner';
    import { Layout } from '@/components/layout/Layout';

    const UserList = lazy(() =>
      import('@/features/users/UserList').then(m => ({ default: m.UserList }))
    );
    const UserDetail = lazy(() =>
      import('@/features/users/UserDetail').then(m => ({ default: m.UserDetail }))
    );
    const UserForm = lazy(() =>
      import('@/features/users/UserForm').then(m => ({ default: m.UserForm }))
    );
    const NotFound = lazy(() =>
      import('@/components/shared/NotFound').then(m => ({ default: m.NotFound }))
    );

    const queryClient = new QueryClient({
      defaultOptions: {
        queries: {
          staleTime: 5 * 60 * 1000,
          retry: 1,
          refetchOnWindowFocus: false,
        },
      },
    });

    export const App: FC = () => {
      return (
        <MsalProvider instance={msalInstance}>
          <QueryClientProvider client={queryClient}>
            <BrowserRouter>
              <AuthGuard>
                <Layout>
                  <Suspense fallback={<Spinner />}>
                    <Routes>
                      <Route path="/" element={<Navigate to="/users" replace />} />
                      <Route path="/users" element={<UserList />} />
                      <Route path="/users/new" element={<UserForm />} />
                      <Route path="/users/:id" element={<UserDetail />} />
                      <Route path="/users/:id/edit" element={<UserForm />} />
                      <Route path="*" element={<NotFound />} />
                    </Routes>
                  </Suspense>
                </Layout>
              </AuthGuard>
            </BrowserRouter>
          </QueryClientProvider>
        </MsalProvider>
      );
    };

---

## File and Folder Structure

    src/
    ├── App.tsx
    ├── main.tsx
    ├── config/
    │   └── authConfig.ts
    ├── lib/
    │   └── apiClient.ts
    ├── models/
    │   └── user.ts
    ├── services/
    │   └── userApi.ts
    ├── hooks/
    │   └── useUsers.ts
    ├── features/
    │   └── users/
    │       ├── UserList.tsx
    │       ├── UserList.test.tsx
    │       ├── UserDetail.tsx
    │       ├── UserDetail.test.tsx
    │       ├── UserForm.tsx
    │       ├── UserForm.test.tsx
    │       ├── UserCard.tsx
    │       └── UserCard.test.tsx
    ├── components/
    │   ├── auth/
    │   │   └── AuthGuard.tsx
    │   ├── layout/
    │   │   ├── Layout.tsx
    │   │   ├── Header.tsx
    │   │   └── Sidebar.tsx
    │   ├── ui/
    │   │   ├── Spinner.tsx
    │   │   ├── ErrorBanner.tsx
    │   │   └── Button.tsx
    │   └── shared/
    │       └── NotFound.tsx
    └── __tests__/
        └── setup.ts

---

## Rules Summary

1. ALWAYS use **functional components** — never class components
2. ALWAYS use **TypeScript** with strict mode — no `any` types
3. ALWAYS use **named exports** — never default exports
4. ALWAYS define **interfaces** for all component props
5. ALWAYS use **React Query (TanStack Query)** for server state
6. ALWAYS use **Zustand** for client-only state (if needed, never Redux for new projects)
7. ALWAYS use **custom hooks** to encapsulate reusable logic
8. ALWAYS use **lazy loading** with React.lazy and Suspense for route components
9. ALWAYS use **React Router v6+** with typed route params
10. ALWAYS colocate test files with components: UserList.tsx next to UserList.test.tsx
11. ALWAYS use `@azure/msal-react` for authentication
12. ALWAYS use `aria-*` attributes for accessibility on form inputs
13. ALWAYS use `role="alert"` on error messages for screen readers
14. ALWAYS handle loading, error, and empty states in every data-fetching component
15. ALWAYS invalidate relevant queries after mutations using queryClient
16. ALWAYS use environment variables via `import.meta.env` (Vite) — never hardcode URLs
17. NEVER use `useEffect` for data fetching — use React Query instead
18. NEVER use default exports — always use named exports for
