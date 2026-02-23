---
agent: agent
description: "Scaffold an Angular standalone component with service, model, routing, and tests"
---

# Create Angular Component

Scaffold a complete Angular standalone component following org standards.
Follow ALL standards from `.specify/memory/constitution.md` and `.github/instructions/angular.instructions.md`.

## Component Details

- **Component name**: ${input:componentName:What is the component name? (e.g., UserList, ProductDetail, OrderForm)}
- **Component type**: ${input:componentType:What type of component? (list, detail, form, card, page):list}
- **API resource**: ${input:apiResource:What API resource does it consume? (e.g., /api/v1/users, /api/v1/products)}
- **Generate tests**: ${input:generateTests:Generate test file? (yes/no):yes}

## Generate the Following Files

### 1. Model / Interface File

File: `{feature}/{component-name}.model.ts`

- Create TypeScript interfaces for:
  - The main entity (e.g., User, Product)
  - Create request DTO (e.g., CreateUserRequest)
  - Update request DTO (e.g., UpdateUserRequest)
  - PagedResult<T> generic wrapper (if not already in project)
- Use strict types — no `any`
- Include JSDoc comments on each interface and property

Example structure:

    export interface User {
      /** Unique user identifier */
      id: string;
      /** User email address */
      email: string;
    }

### 2. Service File

File: `services/{resource}.service.ts`

- Use `@Injectable({ providedIn: 'root' })`
- Inject `HttpClient` and `API_BASE_URL` using `inject()` function
- Create typed methods for all CRUD operations:
  - `getAll(page, pageSize)` → returns `Observable<PagedResult<T>>`
  - `getById(id)` → returns `Observable<T>`
  - `create(request)` → returns `Observable<T>`
  - `update(id, request)` → returns `Observable<T>`
  - `delete(id)` → returns `Observable<void>`
- Use `HttpParams` for query parameters
- Return typed Observables — never `any`

### 3. Component File

File: `{feature}/{component-name}/{component-name}.component.ts`

Requirements for ALL component types:

- Use `standalone: true`
- Use `ChangeDetectionStrategy.OnPush`
- Use `inject()` function for all dependencies — never constructor injection
- Use `signal()` for all component state
- Use `computed()` for derived state
- Use `protected` access modifier for all template-bound members
- Handle three states: loading, error, and success
- Handle empty state (no data)

#### For LIST component type:

- Inject the service
- Create signals: items, isLoading, errorMessage, totalCount
- Create computed: hasItems, isEmpty
- Load data on init with pagination support
- Include search/filter if applicable
- Use `@for` with `track` for rendering list
- Use `@if` for conditional rendering (loading, error, empty)
- Include a refresh/retry mechanism on error

#### For DETAIL component type:

- Inject the service and ActivatedRoute
- Read `id` from route params
- Create signals: item, isLoading, errorMessage
- Load single item by ID on init
- Handle not-found state
- Include navigation back to list
- Include edit and delete action buttons

#### For FORM component type:

- Inject FormBuilder, service, Router, and ActivatedRoute
- Create reactive form using `fb.nonNullable.group()`
- Create signals: isSubmitting, errorMessage, isEditMode
- Determine create vs edit mode from route params (presence of `:id`)
- In edit mode: load existing data and patch form, disable immutable fields
- Add validation: Validators.required, Validators.email, Validators.maxLength as needed
- Submit handler: validate form, call service, navigate on success, show error on failure
- Disable submit button while submitting
- Show field-level validation errors using `@if` with form control error checks

#### For CARD component type:

- Accept entity as `input()` signal
- Display key information from the entity
- Emit events for actions: `selected`, `deleted`
- Use `output()` for event emitters
- Keep the component presentational — no service injection

#### For PAGE component type:

- Act as a routed container component
- Compose child components (list, detail, form)
- Handle routing logic
- Inject service for page-level data

### 4. Template File

File: `{feature}/{component-name}/{component-name}.component.html`

- Use Angular 17+ control flow: `@if`, `@for`, `@switch`, `@empty`
- NEVER use `*ngIf`, `*ngFor`, `*ngSwitch`
- Use `track` in every `@for` loop with a unique identifier
- Include accessibility attributes: `role`, `aria-label`, `aria-live`
- Use `role="alert"` on error messages
- Use `role="progressbar"` on loading spinners
- Use semantic HTML: `<main>`, `<section>`, `<nav>`, `<header>`
- Include `<label>` elements properly associated with form inputs using `for` attribute

### 5. Style File

File: `{feature}/{component-name}/{component-name}.component.scss`

- Use component-scoped styles (Angular default with ViewEncapsulation)
- Use CSS custom properties for theming
- Use BEM naming convention or simple descriptive class names
- Include responsive styles with media queries
- Keep styles minimal — rely on a design system or CSS framework if available

### 6. Route Configuration

Show the route entry to add in the appropriate routes file:

- Use lazy loading with `loadComponent`
- Include `canActivate: [MsalGuard]` for protected routes
- Use meaningful route paths

Example:

    {
      path: 'resource-name',
      canActivate: [MsalGuard],
      loadComponent: () =>
        import('./features/resource/resource-list/resource-list.component')
          .then(m => m.ResourceListComponent)
    }

### 7. Test File (if generateTests is yes)

File: `{feature}/{component-name}/{component-name}.component.spec.ts`

Follow `.github/instructions/jest-vitest-testing.instructions.md`:

- Use `@testing-library/angular` `render()` function
- Mock the service with jest.fn() or vi.fn() methods
- Mock Router and ActivatedRoute if needed

Generate tests for:

**Rendering tests:**

- Component renders without errors
- Displays data when service returns successfully
- Shows loading spinner while fetching
- Shows error message when service fails
- Shows empty state when no data returned

**Interaction tests (for form and list components):**

- User can type in form fields
- Form shows validation errors on invalid submit
- Form submits successfully with valid data and navigates
- Form shows server error on API failure
- Submit button is disabled while submitting
- List items are clickable (if applicable)
- Retry button works after error

**Testing requirements:**

- Use `userEvent` for interactions — never `fireEvent`
- Use `waitFor` for async assertions
- Use Testing Library query priority: getByRole > getByLabelText > getByText > getByTestId
- Mock all HTTP calls via service mock
- Mock MsalService and MsalBroadcastService
- Use `beforeEach` to clear mocks
- Use `of()` and `throwError()` for Observable mocks

## Folder Structure

Show where each file should be placed:

    src/app/
    ├── features/
    │   └── {resource}/
    │       ├── {component-name}/
    │       │   ├── {component-name}.component.ts
    │       │   ├── {component-name}.component.html
    │       │   ├── {component-name}.component.scss
    │       │   └── {component-name}.component.spec.ts
    │       └── {resource}.model.ts
    ├── services/
    │   └── {resource}.service.ts
    └── app.routes.ts (update with new route)

## Code Quality

- Strict TypeScript — no `any` types
- All public methods and properties have JSDoc comments
- Follow Angular CLI naming conventions: kebab-case file names
- Component selector prefix: `app-`
