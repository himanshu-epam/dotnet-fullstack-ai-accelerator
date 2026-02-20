---
applyTo: "**/*.test.ts,**/*.test.tsx,**/*.spec.ts,**/*.spec.tsx,**/jest.config.*,**/vitest.config.*,**/setup.ts,**/test-utils.*"
---

# Jest / Vitest Frontend Testing Instructions

## Overview

- Framework: **Jest** or **Vitest** (team choice, be consistent within project)
- Component testing: **Testing Library** (@testing-library/angular or @testing-library/react)
- User interactions: **userEvent** (NOT fireEvent)
- Minimum **70% code coverage** for components with business logic
- Mock all HTTP calls — NEVER hit real APIs in tests
- Test user-visible behavior, NOT implementation details

## NPM Packages

React testing:

    @testing-library/react
    @testing-library/jest-dom
    @testing-library/user-event
    vitest (or jest)
    @vitejs/plugin-react (for vitest)
    msw (Mock Service Worker — optional, for API mocking)

Angular testing:

    @testing-library/angular
    @testing-library/jest-dom
    @testing-library/user-event
    jest (or vitest)
    jest-preset-angular (for jest)

## Query Priority (Testing Library)

ALWAYS use queries in this priority order:

| Priority | Query                | When to Use                                     |
| :------: | -------------------- | ----------------------------------------------- |
|    1     | getByRole            | Buttons, links, headings, inputs with labels    |
|    2     | getByLabelText       | Form inputs associated with a label             |
|    3     | getByPlaceholderText | Inputs with placeholder (when no label)         |
|    4     | getByText            | Non-interactive text content                    |
|    5     | getByDisplayValue    | Inputs with current value                       |
|    6     | getByAltText         | Images                                          |
|    7     | getByTitle           | Elements with title attribute                   |
|    8     | getByTestId          | LAST RESORT — only when no semantic query works |

## NEVER start with getByTestId. ALWAYS try semantic queries first.

## React Component Test Patterns

### Basic Component Rendering Test

    // UserCard.test.tsx
    import { render, screen } from '@testing-library/react';
    import { UserCard } from './UserCard';

    describe('UserCard', () => {
      const mockUser = {
        id: '1',
        email: 'alice@example.com',
        displayName: 'Alice Johnson',
        createdAt: '2026-01-15T10:00:00Z',
        updatedAt: null
      };

      it('should render user display name', () => {
        render(<UserCard user={mockUser} />);

        expect(screen.getByText('Alice Johnson')).toBeInTheDocument();
      });

      it('should render user email', () => {
        render(<UserCard user={mockUser} />);

        expect(screen.getByText('alice@example.com')).toBeInTheDocument();
      });

      it('should render created date in readable format', () => {
        render(<UserCard user={mockUser} />);

        expect(screen.getByText(/jan.*2026/i)).toBeInTheDocument();
      });
    });

### Component with User Interactions

    // UserList.test.tsx
    import { render, screen, waitFor } from '@testing-library/react';
    import userEvent from '@testing-library/user-event';
    import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
    import { UserList } from './UserList';
    import { userApi } from '@/services/userApi';

    vi.mock('@/services/userApi');

    describe('UserList', () => {
      const mockUsers = {
        items: [
          { id: '1', email: 'alice@example.com', displayName: 'Alice', createdAt: '2026-01-15T10:00:00Z', updatedAt: null },
          { id: '2', email: 'bob@example.com', displayName: 'Bob', createdAt: '2026-01-16T10:00:00Z', updatedAt: null }
        ],
        totalCount: 2,
        page: 1,
        pageSize: 20,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      };

      function renderWithProviders(ui: React.ReactElement) {
        const queryClient = new QueryClient({
          defaultOptions: {
            queries: { retry: false }
          }
        });
        return render(
          <QueryClientProvider client={queryClient}>
            {ui}
          </QueryClientProvider>
        );
      }

      beforeEach(() => {
        vi.clearAllMocks();
      });

      it('should render list of users when data loads successfully', async () => {
        vi.mocked(userApi.getAll).mockResolvedValue(mockUsers);

        renderWithProviders(<UserList />);

        await waitFor(() => {
          expect(screen.getByText('Alice')).toBeInTheDocument();
          expect(screen.getByText('Bob')).toBeInTheDocument();
        });
      });

      it('should display loading spinner while fetching data', () => {
        vi.mocked(userApi.getAll).mockReturnValue(new Promise(() => {}));

        renderWithProviders(<UserList />);

        expect(screen.getByRole('progressbar')).toBeInTheDocument();
      });

      it('should display error message when API call fails', async () => {
        vi.mocked(userApi.getAll).mockRejectedValue(new Error('Network error'));

        renderWithProviders(<UserList />);

        await waitFor(() => {
          expect(screen.getByRole('alert')).toBeInTheDocument();
          expect(screen.getByText(/failed to load/i)).toBeInTheDocument();
        });
      });

      it('should display empty state when no users found', async () => {
        vi.mocked(userApi.getAll).mockResolvedValue({
          ...mockUsers,
          items: [],
          totalCount: 0
        });

        renderWithProviders(<UserList />);

        await waitFor(() => {
          expect(screen.getByText(/no users found/i)).toBeInTheDocument();
        });
      });

      it('should call retry when retry button is clicked after error', async () => {
        const user = userEvent.setup();
        vi.mocked(userApi.getAll)
          .mockRejectedValueOnce(new Error('Network error'))
          .mockResolvedValueOnce(mockUsers);

        renderWithProviders(<UserList />);

        await waitFor(() => {
          expect(screen.getByText(/failed to load/i)).toBeInTheDocument();
        });

        await user.click(screen.getByRole('button', { name: /retry/i }));

        await waitFor(() => {
          expect(screen.getByText('Alice')).toBeInTheDocument();
        });
      });
    });

---

## React Form Test Patterns

    // UserForm.test.tsx
    import { render, screen, waitFor } from '@testing-library/react';
    import userEvent from '@testing-library/user-event';
    import { BrowserRouter } from 'react-router-dom';
    import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
    import { UserForm } from './UserForm';
    import { userApi } from '@/services/userApi';

    vi.mock('@/services/userApi');

    const mockNavigate = vi.fn();
    vi.mock('react-router-dom', async () => {
      const actual = await vi.importActual('react-router-dom');
      return {
        ...actual,
        useNavigate: () => mockNavigate,
        useParams: () => ({})
      };
    });

    describe('UserForm', () => {
      function renderForm() {
        const queryClient = new QueryClient({
          defaultOptions: { queries: { retry: false } }
        });
        return render(
          <QueryClientProvider client={queryClient}>
            <BrowserRouter>
              <UserForm />
            </BrowserRouter>
          </QueryClientProvider>
        );
      }

      beforeEach(() => {
        vi.clearAllMocks();
      });

      it('should render email and display name fields', () => {
        renderForm();

        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
        expect(screen.getByLabelText(/display name/i)).toBeInTheDocument();
      });

      it('should render submit button with create text', () => {
        renderForm();

        expect(screen.getByRole('button', { name: /create user/i })).toBeInTheDocument();
      });

      it('should show validation error when email is empty on submit', async () => {
        const user = userEvent.setup();
        renderForm();

        await user.click(screen.getByRole('button', { name: /create user/i }));

        await waitFor(() => {
          expect(screen.getByText(/email is required/i)).toBeInTheDocument();
        });
      });

      it('should show validation error when email format is invalid', async () => {
        const user = userEvent.setup();
        renderForm();

        await user.type(screen.getByLabelText(/email/i), 'not-an-email');
        await user.type(screen.getByLabelText(/display name/i), 'Valid Name');
        await user.click(screen.getByRole('button', { name: /create user/i }));

        await waitFor(() => {
          expect(screen.getByText(/valid email/i)).toBeInTheDocument();
        });
      });

      it('should show validation error when display name is empty', async () => {
        const user = userEvent.setup();
        renderForm();

        await user.type(screen.getByLabelText(/email/i), 'valid@example.com');
        await user.click(screen.getByRole('button', { name: /create user/i }));

        await waitFor(() => {
          expect(screen.getByText(/display name is required/i)).toBeInTheDocument();
        });
      });

      it('should call create API and navigate on successful submit', async () => {
        const user = userEvent.setup();
        vi.mocked(userApi.create).mockResolvedValue({
          id: '1',
          email: 'new@example.com',
          displayName: 'New User',
          createdAt: '2026-01-15T10:00:00Z',
          updatedAt: null
        });

        renderForm();

        await user.type(screen.getByLabelText(/email/i), 'new@example.com');
        await user.type(screen.getByLabelText(/display name/i), 'New User');
        await user.click(screen.getByRole('button', { name: /create user/i }));

        await waitFor(() => {
          expect(userApi.create).toHaveBeenCalledWith({
            email: 'new@example.com',
            displayName: 'New User'
          });
          expect(mockNavigate).toHaveBeenCalledWith('/users');
        });
      });

      it('should show server error when API call fails', async () => {
        const user = userEvent.setup();
        vi.mocked(userApi.create).mockRejectedValue(new Error('Server error'));

        renderForm();

        await user.type(screen.getByLabelText(/email/i), 'new@example.com');
        await user.type(screen.getByLabelText(/display name/i), 'New User');
        await user.click(screen.getByRole('button', { name: /create user/i }));

        await waitFor(() => {
          expect(screen.getByRole('alert')).toBeInTheDocument();
          expect(screen.getByText(/failed to save/i)).toBeInTheDocument();
        });
      });

      it('should disable submit button while submitting', async () => {
        const user = userEvent.setup();
        vi.mocked(userApi.create).mockReturnValue(new Promise(() => {}));

        renderForm();

        await user.type(screen.getByLabelText(/email/i), 'new@example.com');
        await user.type(screen.getByLabelText(/display name/i), 'New User');
        await user.click(screen.getByRole('button', { name: /create user/i }));

        await waitFor(() => {
          expect(screen.getByRole('button', { name: /saving/i })).toBeDisabled();
        });
      });
    });

---

## Angular Component Test Patterns

### Basic Component Test

    // user-card.component.spec.ts
    import { render, screen } from '@testing-library/angular';
    import { UserCardComponent } from './user-card.component';

    describe('UserCardComponent', () => {
      const mockUser = {
        id: '1',
        email: 'alice@example.com',
        displayName: 'Alice Johnson',
        createdAt: '2026-01-15T10:00:00Z',
        updatedAt: null
      };

      it('should render user display name', async () => {
        await render(UserCardComponent, {
          inputs: { user: mockUser }
        });

        expect(screen.getByText('Alice Johnson')).toBeInTheDocument();
      });

      it('should render user email', async () => {
        await render(UserCardComponent, {
          inputs: { user: mockUser }
        });

        expect(screen.getByText('alice@example.com')).toBeInTheDocument();
      });
    });

### Component with Service Dependency

    // user-list.component.spec.ts
    import { render, screen, waitFor } from '@testing-library/angular';
    import userEvent from '@testing-library/user-event';
    import { of, throwError } from 'rxjs';
    import { UserListComponent } from './user-list.component';
    import { UserService } from '@app/services/user.service';

    describe('UserListComponent', () => {
      const mockUsers = {
        items: [
          { id: '1', email: 'alice@example.com', displayName: 'Alice', createdAt: '2026-01-15T10:00:00Z', updatedAt: null },
          { id: '2', email: 'bob@example.com', displayName: 'Bob', createdAt: '2026-01-16T10:00:00Z', updatedAt: null }
        ],
        totalCount: 2,
        page: 1,
        pageSize: 20,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      };

      const mockUserService = {
        getAll: jest.fn()
      };

      beforeEach(() => {
        jest.clearAllMocks();
      });

      it('should render list of users when service returns data', async () => {
        mockUserService.getAll.mockReturnValue(of(mockUsers));

        await render(UserListComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService }
          ]
        });

        await waitFor(() => {
          expect(screen.getByText('Alice')).toBeInTheDocument();
          expect(screen.getByText('Bob')).toBeInTheDocument();
        });
      });

      it('should display loading spinner while fetching data', async () => {
        mockUserService.getAll.mockReturnValue(new Observable(() => {}));

        await render(UserListComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService }
          ]
        });

        expect(screen.getByRole('progressbar')).toBeInTheDocument();
      });

      it('should display error message when service fails', async () => {
        mockUserService.getAll.mockReturnValue(throwError(() => new Error('Network error')));

        await render(UserListComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService }
          ]
        });

        await waitFor(() => {
          expect(screen.getByRole('alert')).toBeInTheDocument();
          expect(screen.getByText(/failed to load/i)).toBeInTheDocument();
        });
      });

      it('should display empty state when no users found', async () => {
        mockUserService.getAll.mockReturnValue(of({
          ...mockUsers,
          items: [],
          totalCount: 0
        }));

        await render(UserListComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService }
          ]
        });

        await waitFor(() => {
          expect(screen.getByText(/no users found/i)).toBeInTheDocument();
        });
      });
    });

### Angular Form Component Test

    // user-form.component.spec.ts
    import { render, screen, waitFor } from '@testing-library/angular';
    import userEvent from '@testing-library/user-event';
    import { of, throwError } from 'rxjs';
    import { Router } from '@angular/router';
    import { UserFormComponent } from './user-form.component';
    import { UserService } from '@app/services/user.service';

    describe('UserFormComponent', () => {
      const mockUserService = {
        create: jest.fn(),
        getById: jest.fn(),
        update: jest.fn()
      };

      const mockRouter = {
        navigate: jest.fn()
      };

      beforeEach(() => {
        jest.clearAllMocks();
      });

      it('should render email and display name fields', async () => {
        await render(UserFormComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService },
            { provide: Router, useValue: mockRouter }
          ]
        });

        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
        expect(screen.getByLabelText(/display name/i)).toBeInTheDocument();
      });

      it('should show validation error when email is empty on submit', async () => {
        const user = userEvent.setup();

        await render(UserFormComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService },
            { provide: Router, useValue: mockRouter }
          ]
        });

        await user.click(screen.getByRole('button', { name: /create/i }));

        await waitFor(() => {
          expect(screen.getByText(/email is required/i)).toBeInTheDocument();
        });
      });

      it('should call create service and navigate on valid submit', async () => {
        const user = userEvent.setup();
        mockUserService.create.mockReturnValue(of({
          id: '1',
          email: 'new@example.com',
          displayName: 'New User',
          createdAt: '2026-01-15T10:00:00Z',
          updatedAt: null
        }));

        await render(UserFormComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService },
            { provide: Router, useValue: mockRouter }
          ]
        });

        await user.type(screen.getByLabelText(/email/i), 'new@example.com');
        await user.type(screen.getByLabelText(/display name/i), 'New User');
        await user.click(screen.getByRole('button', { name: /create/i }));

        await waitFor(() => {
          expect(mockUserService.create).toHaveBeenCalledWith({
            email: 'new@example.com',
            displayName: 'New User'
          });
          expect(mockRouter.navigate).toHaveBeenCalledWith(['/users']);
        });
      });

      it('should show server error when API call fails', async () => {
        const user = userEvent.setup();
        mockUserService.create.mockReturnValue(throwError(() => new Error('Server error')));

        await render(UserFormComponent, {
          providers: [
            { provide: UserService, useValue: mockUserService },
            { provide: Router, useValue: mockRouter }
          ]
        });

        await user.type(screen.getByLabelText(/email/i), 'new@example.com');
        await user.type(screen.getByLabelText(/display name/i), 'New User');
        await user.click(screen.getByRole('button', { name: /create/i }));

        await waitFor(() => {
          expect(screen.getByRole('alert')).toBeInTheDocument();
          expect(screen.getByText(/failed to save/i)).toBeInTheDocument();
        });
      });
    });

---

## React Custom Hook Test Pattern

    // useUsers.test.ts
    import { renderHook, waitFor } from '@testing-library/react';
    import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
    import { useUsers, useCreateUser } from './useUsers';
    import { userApi } from '@/services/userApi';
    import { ReactNode } from 'react';

    vi.mock('@/services/userApi');

    describe('useUsers', () => {
      function createWrapper() {
        const queryClient = new QueryClient({
          defaultOptions: { queries: { retry: false } }
        });
        return ({ children }: { children: ReactNode }) => (
          <QueryClientProvider client={queryClient}>
            {children}
          </QueryClientProvider>
        );
      }

      it('should return users when API call succeeds', async () => {
        const mockData = {
          items: [{ id: '1', email: 'test@example.com', displayName: 'Test', createdAt: '', updatedAt: null }],
          totalCount: 1,
          page: 1,
          pageSize: 20,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        };
        vi.mocked(userApi.getAll).mockResolvedValue(mockData);

        const { result } = renderHook(() => useUsers(), { wrapper: createWrapper() });

        await waitFor(() => {
          expect(result.current.data).toEqual(mockData);
          expect(result.current.isLoading).toBe(false);
        });
      });

      it('should return error when API call fails', async () => {
        vi.mocked(userApi.getAll).mockRejectedValue(new Error('Network error'));

        const { result } = renderHook(() => useUsers(), { wrapper: createWrapper() });

        await waitFor(() => {
          expect(result.current.error).toBeDefined();
          expect(result.current.isLoading).toBe(false);
        });
      });
    });

---

## Angular Service Test Pattern

    // user.service.spec.ts
    import { TestBed } from '@angular/core/testing';
    import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
    import { UserService } from './user.service';
    import { API_BASE_URL } from '@app/config/api.config';

    describe('UserService', () => {
      let service: UserService;
      let httpMock: HttpTestingController;
      const baseUrl = 'https://localhost:7001';

      beforeEach(() => {
        TestBed.configureTestingModule({
          imports: [HttpClientTestingModule],
          providers: [
            UserService,
            { provide: API_BASE_URL, useValue: baseUrl }
          ]
        });

        service = TestBed.inject(UserService);
        httpMock = TestBed.inject(HttpTestingController);
      });

      afterEach(() => {
        httpMock.verify();
      });

      it('should fetch all users with pagination', () => {
        const mockResponse = {
          items: [{ id: '1', email: 'test@example.com', displayName: 'Test', createdAt: '', updatedAt: null }],
          totalCount: 1,
          page: 1,
          pageSize: 20,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        };

        service.getAll(1, 20).subscribe(result => {
          expect(result).toEqual(mockResponse);
          expect(result.items.length).toBe(1);
        });

        const req = httpMock.expectOne(`${baseUrl}/api/v1/users?page=1&pageSize=20`);
        expect(req.request.method).toBe('GET');
        req.flush(mockResponse);
      });

      it('should create a user', () => {
        const request = { email: 'new@example.com', displayName: 'New User' };
        const mockResponse = {
          id: '1',
          ...request,
          createdAt: '2026-01-15T10:00:00Z',
          updatedAt: null
        };

        service.create(request).subscribe(result => {
          expect(result).toEqual(mockResponse);
        });

        const req = httpMock.expectOne(`${baseUrl}/api/v1/users`);
        expect(req.request.method).toBe('POST');
        expect(req.request.body).toEqual(request);
        req.flush(mockResponse);
      });

      it('should handle HTTP error gracefully', () => {
        service.getAll().subscribe({
          error: (error) => {
            expect(error.status).toBe(500);
          }
        });

        const req = httpMock.expectOne(`${baseUrl}/api/v1/users?page=1&pageSize=20`);
        req.flush('Server Error', { status: 500, statusText: 'Internal Server Error' });
      });
    });

---

## Test Setup File

### Vitest Setup (React)

    // src/__tests__/setup.ts
    import '@testing-library/jest-dom/vitest';
    import { cleanup } from '@testing-library/react';
    import { afterEach, vi } from 'vitest';

    // Cleanup after each test
    afterEach(() => {
      cleanup();
    });

    // Mock window.matchMedia
    Object.defineProperty(window, 'matchMedia', {
      writable: true,
      value: vi.fn().mockImplementation((query: string) => ({
        matches: false,
        media: query,
        onchange: null,
        addListener: vi.fn(),
        removeListener: vi.fn(),
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
        dispatchEvent: vi.fn()
      }))
    });

### Vitest Config

    // vitest.config.ts
    import { defineConfig } from 'vitest/config';
    import react from '@vitejs/plugin-react';
    import path from 'path';

    export default defineConfig({
      plugins: [react()],
      test: {
        globals: true,
        environment: 'jsdom',
        setupFiles: './src/__tests__/setup.ts',
        css: true,
        coverage: {
          provider: 'v8',
          reporter: ['text', 'lcov', 'html'],
          exclude: [
            'node_modules/',
            'src/__tests__/',
            '**/*.d.ts',
            '**/*.config.*',
            '**/main.tsx'
          ],
          thresholds: {
            statements: 70,
            branches: 70,
            functions: 70,
            lines: 70
          }
        }
      },
      resolve: {
        alias: {
          '@': path.resolve(__dirname, './src')
        }
      }
    });

---

## Custom Render Utility (React)

    // test-utils.tsx
    import { ReactElement, ReactNode } from 'react';
    import { render, RenderOptions } from '@testing-library/react';
    import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
    import { BrowserRouter } from 'react-router-dom';

    function createTestQueryClient() {
      return new QueryClient({
        defaultOptions: {
          queries: { retry: false },
          mutations: { retry: false }
        }
      });
    }

    interface WrapperProps {
      children: ReactNode;
    }

    function AllProviders({ children }: WrapperProps) {
      const queryClient = createTestQueryClient();
      return (
        <QueryClientProvider client={queryClient}>
          <BrowserRouter>
            {children}
          </BrowserRouter>
        </QueryClientProvider>
      );
    }

    function customRender(
      ui: ReactElement,
      options?: Omit<RenderOptions, 'wrapper'>
    ) {
      return render(ui, { wrapper: AllProviders, ...options });
    }

    export * from '@testing-library/react';
    export { customRender as render };

Usage in tests:

    // Import from test-utils instead of @testing-library/react
    import { render, screen, waitFor } from '@/__tests__/test-utils';

---

## Mocking Authentication in Tests

### React — Mock useAuth Hook

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

### Angular — Mock AuthService

    const mockAuthService = {
      isAuthenticated: signal(true),
      currentUser: signal({
        id: '00000000-0000-0000-0000-000000000001',
        email: 'test@example.com',
        displayName: 'Test User',
        roles: ['User', 'Admin']
      }),
      hasAdminRole: signal(true),
      login: jest.fn(),
      logout: jest.fn(),
      hasRole: jest.fn().mockReturnValue(true)
    };

    await render(ComponentUnderTest, {
      providers: [
        { provide: AuthService, useValue: mockAuthService }
      ]
    });

### React — Mock MSAL (When Needed Directly)

    vi.mock('@azure/msal-react', () => ({
      useMsal: () => ({
        instance: {
          getActiveAccount: vi.fn().mockReturnValue({
            localAccountId: '00000000-0000-0000-0000-000000000001',
            username: 'test@example.com',
            name: 'Test User'
          }),
          acquireTokenSilent: vi.fn().mockResolvedValue({
            accessToken: 'mock-token'
          })
        },
        accounts: [{
          localAccountId: '00000000-0000-0000-0000-000000000001',
          username: 'test@example.com',
          name: 'Test User'
        }]
      }),
      useIsAuthenticated: () => true,
      MsalProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
      MsalAuthenticationTemplate: ({ children }: { children: React.ReactNode }) => <>{children}</>
    }));

---

## Test File Organization

React:

    src/features/users/
    ├── UserList.tsx
    ├── UserList.test.tsx       ← Colocated with component
    ├── UserForm.tsx
    ├── UserForm.test.tsx       ← Colocated with component
    ├── UserCard.tsx
    └── UserCard.test.tsx       ← Colocated with component
    src/hooks/
    ├── useUsers.ts
    └── useUsers.test.ts        ← Colocated with hook
    src/services/
    ├── userApi.ts
    └── userApi.test.ts         ← Colocated with service

Angular:

    src/app/features/users/user-list/
    ├── user-list.component.ts
    ├── user-list.component.html
    ├── user-list.component.scss
    └── user-list.component.spec.ts    ← Colocated with component
    src/app/services/
    ├── user.service.ts
    └── user.service.spec.ts           ← Colocated with service

---

## Rules Summary

### General Rules

1. Use **Testing Library** for all component tests — NEVER use Enzyme
2. Use **userEvent** for interactions — NEVER use fireEvent
3. Use **waitFor** for async assertions
4. Test user-visible behavior, NOT implementation details
5. Mock all HTTP calls — NEVER hit real APIs
6. Mock authentication — NEVER use real Entra ID tokens
7. Clean up after each test (Testing Library does this automatically with cleanup)
8. Colocate test files with source files

### Query Rules

9. ALWAYS follow Testing Library query priority: getByRole first, getByTestId last
10. NEVER start with getByTestId — try semantic queries first
11. Use regex patterns for flexible text matching: /submit/i instead of exact strings
12. Use getByRole with name option for buttons and links: getByRole('button', { name: /save/i })

### Assertion Rules

13. ALWAYS use @testing-library/jest-dom matchers (toBeInTheDocument, toBeDisabled, etc.)
14. Use toBeInTheDocument() to verify elements exist
15. Use toBeDisabled() and toBeEnabled() for form control states
16. Use toHaveValue() for input values
17. Use role="alert" on error messages for accessibility AND testability

### Mock Rules

18. ALWAYS call vi.clearAllMocks() or jest.clearAllMocks() in beforeEach
19. Use vi.mock() or jest.mock() at the top of the test file
20. Use vi.mocked() or jest.mocked() for type-safe mock access
21. Mock at the service/hook level — not at the HTTP client level (unless testing the service itself)
22. Use mockResolvedValue for successful API calls
23. Use mockRejectedValue for failed API calls
24. Use mockReturnValue(new Promise(() => {})) for loading states

### React-Specific Rules

25. ALWAYS create a custom render utility with providers (QueryClient, Router)
26. ALWAYS use renderHook for testing custom hooks
27. ALWAYS wrap hook tests with QueryClientProvider if hook uses React Query
28. ALWAYS disable retry in test QueryClient: { queries: { retry: false } }

### Angular-Specific Rules

29. ALWAYS use @testing-library/angular render() — not TestBed directly
30. ALWAYS provide mock services via providers array
31. ALWAYS use HttpTestingController for service tests
32. ALWAYS call httpMock.verify() in afterEach

### Coverage Rules

33. Minimum 70% code coverage for components with business logic
34. Test all states: loading, success, error, empty
35. Test form validation: required fields, format validation, max lengths
36. Test user interactions: click, type, submit
37. Test navigation: redirects after form submission
