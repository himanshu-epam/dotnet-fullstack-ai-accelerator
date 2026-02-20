---
agent: agent
description: "Scaffold a React functional component with hooks, API service, routing, and tests"
---

# Create React Component

Scaffold a complete React functional component following org standards.
Follow ALL standards from `.specify/memory/constitution.md` and `.github/instructions/react.instructions.md`.

## Component Details

- **Component name**: ${input:componentName:What is the component name? (e.g., UserList, ProductDetail, OrderForm)}
- **Component type**: ${input:componentType:What type of component? (list, detail, form, card, page):list}
- **API resource**: ${input:apiResource:What API resource does it consume? (e.g., /api/v1/users, /api/v1/products)}
- **Generate tests**: ${input:generateTests:Generate test file? (yes/no):yes}

## Generate the Following Files

### 1. Model / Interface File

File: `models/{resource}.ts`

- Create TypeScript interfaces for:
  - The main entity (e.g., User, Product)
  - Create request DTO (e.g., CreateUserRequest)
  - Update request DTO (e.g., UpdateUserRequest)
  - PagedResult<T> generic wrapper (if not already in project)
- Use strict types — no `any`
- Include JSDoc comments on each interface and property
- Use named exports — never default exports

Example structure:

    /** Represents a user in the system */
    export interface User {
      /** Unique user identifier */
      id: string;
      /** User email address */
      email: string;
      /** User display name */
      displayName: string;
      /** When the user was created */
      createdAt: string;
      /** When the user was last updated, null if never updated */
      updatedAt: string | null;
    }

### 2. API Service File

File: `services/{resource}Api.ts`

- Import `apiClient` from `@/lib/apiClient`
- Create an object with typed async functions for all CRUD operations:
  - `getAll(page, pageSize)` → returns `Promise<PagedResult<T>>`
  - `getById(id)` → returns `Promise<T>`
  - `create(data)` → returns `Promise<T>`
  - `update(id, data)` → returns `Promise<T>`
  - `delete(id)` → returns `Promise<void>`
- All functions use `apiClient.get/post/put/delete` with typed responses
- Use named export for the API object
- Never use `any` — all parameters and return types must be typed

Example structure:

    export const userApi = {
      getAll: async (page: number = 1, pageSize: number = 20): Promise<PagedResult<User>> => {
        const response = await apiClient.get<PagedResult<User>>('/api/v1/users', {
          params: { page, pageSize },
        });
        return response.data;
      },
    };

### 3. Custom Hook File

File: `hooks/use{Resource}s.ts`

- Create custom hooks using React Query (TanStack Query):
  - `use{Resource}s(page, pageSize)` → useQuery for list with pagination
  - `use{Resource}(id)` → useQuery for single item (with `enabled: !!id`)
  - `useCreate{Resource}()` → useMutation with queryClient.invalidateQueries on success
  - `useUpdate{Resource}()` → useMutation with queryClient.invalidateQueries on success
  - `useDelete{Resource}()` → useMutation with queryClient.invalidateQueries on success
- Define a constant query key: `const RESOURCE_QUERY_KEY = ['resources'] as const`
- Use named exports for all hooks
- Include proper TypeScript types on all hooks

### 4. Component File

File: `features/{resource}/{ComponentName}.tsx`

Requirements for ALL component types:

- Use named export: `export const ComponentName: FC<Props> = ...`
- Define interfaces for all props
- Use strict TypeScript — no `any`
- Handle three states: loading, error, and success
- Handle empty state (no data)
- Use `aria-*` attributes for accessibility
- Use `role="alert"` on error messages
- Use `role="progressbar"` on loading spinners

#### For LIST component type:

- Use the `use{Resource}s()` custom hook for data fetching
- Destructure: `data`, `isLoading`, `error`, `refetch`
- Render loading spinner when `isLoading` is true
- Render error banner with retry button when `error` exists
- Render empty state when items array is empty
- Render list of card components when data exists
- Include pagination controls if applicable
- Accept optional filter/search props

Example structure:

    export const UserList: FC = () => {
      const [page, setPage] = useState(1);
      const { data, isLoading, error, refetch } = useUsers(page);

      if (isLoading) return <Spinner />;
      if (error) return <ErrorBanner message="Failed to load users." onRetry={refetch} />;
      if (!data?.items.length) return <EmptyState message="No users found." />;

      return (
        <div className="user-list">
          <h2>Users ({data.totalCount})</h2>
          {data.items.map((user) => (
            <UserCard key={user.id} user={user} />
          ))}
        </div>
      );
    };

#### For DETAIL component type:

- Use `useParams<{ id: string }>()` to get ID from URL
- Use the `use{Resource}(id)` custom hook
- Handle loading, error, not-found states
- Display entity details
- Include navigation back to list
- Include edit and delete action buttons
- Use `useNavigate()` for navigation
- Use `useDelete{Resource}()` for delete action with confirmation

#### For FORM component type:

- Use `useParams<{ id: string }>()` to determine create vs edit mode
- Use `useNavigate()` for navigation after submit
- Use `useState` for form fields, errors, and submission state
- In edit mode: use `use{Resource}(id)` to load existing data
- In edit mode: populate form fields from loaded data
- Client-side validation matching API validation rules
- Submit handler:
  - Validate all fields
  - Call `useCreate{Resource}()` or `useUpdate{Resource}()` mutation
  - Navigate to list on success
  - Show error banner on failure
- Disable submit button while `isPending` is true
- Show "Saving..." text on button while submitting
- Show field-level validation errors with `role="alert"`
- Use `<label htmlFor>` properly associated with inputs
- Use `aria-invalid` and `aria-describedby` on inputs with errors
- Use `noValidate` on form element (we handle validation ourselves)

#### For CARD component type:

- Accept entity as prop with typed interface
- Accept optional event handler props: `onSelect`, `onDelete`
- Display key information from the entity
- Keep the component presentational — no hooks for data fetching
- Use semantic HTML and accessibility attributes

#### For PAGE component type:

- Act as a routed container component
- Compose child components (list, detail, form)
- Handle routing logic with `<Outlet>` if using nested routes
- Wrap with any page-level providers if needed

### 5. Route Configuration

Show the route entries to add in the routing configuration:

- Use React.lazy for code splitting
- Wrap with Suspense and Spinner fallback
- Include inside AuthGuard protected routes

Example:

    const UserList = lazy(() =>
      import('@/features/users/UserList').then(m => ({ default: m.UserList }))
    );
    const UserDetail = lazy(() =>
      import('@/features/users/UserDetail').then(m => ({ default: m.UserDetail }))
    );
    const UserForm = lazy(() =>
      import('@/features/users/UserForm').then(m => ({ default: m.UserForm }))
    );

    // Inside Routes:
    <Route path="/users" element={<UserList />} />
    <Route path="/users/new" element={<UserForm />} />
    <Route path="/users/:id" element={<UserDetail />} />
    <Route path="/users/:id/edit" element={<UserForm />} />

### 6. Test File (if generateTests is yes)

File: `features/{resource}/{ComponentName}.test.tsx`

Follow `.github/instructions/jest-vitest-testing.instructions.md`:

- Import `render`, `screen`, `waitFor` from `@testing-library/react` or custom test-utils
- Import `userEvent` from `@testing-library/user-event`
- Mock the API service: `vi.mock('@/services/{resource}Api')`
- Mock react-router-dom: useNavigate, useParams
- Create `renderWithProviders` helper wrapping QueryClientProvider and BrowserRouter

Generate tests for:

**Rendering tests:**

- Component renders without errors
- Displays data when API returns successfully
- Shows loading spinner while fetching
- Shows error message with retry button when API fails
- Shows empty state when no data returned

**Interaction tests (for form and list components):**

- User can type in form fields
- Form shows validation errors when submitting empty required fields
- Form shows validation errors for invalid email format
- Form shows validation errors for exceeded max length
- Form submits successfully with valid data
- Form calls correct API method (create or update)
- Form navigates to list after successful submit
- Form shows server error banner when API call fails
- Submit button is disabled and shows "Saving..." while submitting
- Delete button triggers confirmation and calls delete API
- Retry button calls refetch after error

**Testing requirements:**

- Use `userEvent.setup()` at the start of interaction tests
- Use `waitFor` for all async assertions
- Use Testing Library query priority: getByRole > getByLabelText > getByText > getByTestId
- Use `vi.mocked()` for type-safe mock access
- Use `vi.clearAllMocks()` in `beforeEach`
- Use `mockResolvedValue` for success, `mockRejectedValue` for failure
- Use `new Promise(() => {})` for loading state tests
- Mock useAuth hook for authentication context
- Create QueryClient with `{ queries: { retry: false } }` for tests

## Folder Structure

Show where each file should be placed:

    src/
    ├── models/
    │   └── {resource}.ts
    ├── services/
    │   └── {resource}Api.ts
    ├── hooks/
    │   └── use{Resource}s.ts
    ├── features/
    │   └── {resource}/
    │       ├── {ComponentName}.tsx
    │       ├── {ComponentName}.test.tsx
    │       ├── {ComponentName}Detail.tsx         (if detail needed)
    │       ├── {ComponentName}Detail.test.tsx
    │       ├── {ComponentName}Form.tsx           (if form needed)
    │       ├── {ComponentName}Form.test.tsx
    │       ├── {ComponentName}Card.tsx           (if card needed)
    │       └── {ComponentName}Card.test.tsx
    └── App.tsx (update with new routes)

## Code Quality

- Strict TypeScript — no `any` types
- Named exports only — never default exports
- All props interfaces defined
- All public functions have JSDoc comments
- Colocate test files with components
- Follow existing project patterns for styling (CSS Modules, Tailwind, styled-components)
