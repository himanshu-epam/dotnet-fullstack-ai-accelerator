---
agent: agent
description: "Generate unit tests for backend (.NET/xUnit) or frontend (Jest/Vitest) code"
---

# Create Unit Tests

You are helping the developer generate comprehensive unit tests.
Follow the organization's constitution at `.specify/memory/constitution.md` — specifically
Section 5 (Testing Standards) and Section 7 (Code Quality).

## Inputs

- **Target File**: ${input:targetFile:Path to the file you want to test (e.g., Services/ProductService.cs or components/ProductList.tsx)}
- **Test Framework**: ${input:framework:xunit|jest|vitest}
- **Coverage Goal**: ${input:coverageGoal:80}

## Step 1 — Backend Unit Tests (xUnit)

Use this step when the target file is a C# class (.cs file).

### Test File Location

- Place tests in the corresponding test project under the matching folder structure
- File name: `{ClassName}Tests.cs`
- Example: `src/MyApp.Application/Services/ProductService.cs`
  maps to `tests/MyApp.Tests.Unit/Services/ProductServiceTests.cs`

### Test Class Structure Rules

- Test class MUST be `public sealed class`
- Use constructor injection for shared setup (xUnit creates a new instance per test)
- Use `IClassFixture<T>` only for expensive shared state
- Group tests logically using `#region` or nested classes
- Add XML doc comments on the test class describing what is being tested

### Test Method Naming Convention

    MethodName_Should_ExpectedBehavior_When_Condition

Examples:

- `GetById_Should_ReturnProduct_When_ProductExists`
- `Create_Should_ThrowValidationException_When_NameIsEmpty`
- `Delete_Should_ReturnFalse_When_ProductNotFound`

### Test Body Pattern (AAA)

Every test MUST follow Arrange-Act-Assert with comment markers:

    [Fact]
    public async Task GetById_Should_ReturnProduct_When_ProductExists()
    {
        // Arrange
        var productId = Guid.NewGuid();
        var expected = new Product { Id = productId, Name = "Test" };
        _repository.GetByIdAsync(productId).Returns(expected);

        // Act
        var result = await _sut.GetByIdAsync(productId);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(expected.Name, result.Name);
    }

### Mocking Rules

- Use **NSubstitute** as the preferred mocking library
- Mock ALL external dependencies (repositories, HTTP clients, loggers)
- NEVER mock the class under test (the SUT)
- Use `Arg.Any<T>()` for flexible argument matching
- Use `Arg.Is<T>(x => x.Property == value)` for specific matching
- Verify interactions with `Received()` and `DidNotReceive()`

### What to Test

For each public method in the target class, generate tests for:

1. **Happy path** — Normal input returns expected output
2. **Null/empty input** — Null or empty parameters handled correctly
3. **Not found** — Entity does not exist
4. **Validation failure** — Invalid input rejected
5. **Authorization** — Unauthorized access handled (if applicable)
6. **Edge cases** — Boundary values, max lengths, special characters
7. **Exception scenarios** — External dependency throws exception

### Example Test Class Pattern

    using NSubstitute;
    using NSubstitute.ReturnsExtensions;

    namespace MyApp.Tests.Unit.Services;

    /// <summary>
    /// Unit tests for <see cref="ProductService"/>.
    /// </summary>
    public sealed class ProductServiceTests
    {
        private readonly IProductRepository _repository;
        private readonly ILogger<ProductService> _logger;
        private readonly ProductService _sut;

        public ProductServiceTests()
        {
            _repository = Substitute.For<IProductRepository>();
            _logger = Substitute.For<ILogger<ProductService>>();
            _sut = new ProductService(_repository, _logger);
        }

        [Fact]
        public async Task GetByIdAsync_Should_ReturnProduct_When_ProductExists()
        {
            // Arrange
            var productId = Guid.NewGuid();
            var expected = new Product { Id = productId, Name = "Widget" };
            _repository.GetByIdAsync(productId, Arg.Any<CancellationToken>())
                .Returns(expected);

            // Act
            var result = await _sut.GetByIdAsync(productId);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(expected.Id, result.Id);
            Assert.Equal(expected.Name, result.Name);
        }

        [Fact]
        public async Task GetByIdAsync_Should_ReturnNull_When_ProductNotFound()
        {
            // Arrange
            _repository.GetByIdAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>())
                .ReturnsNull();

            // Act
            var result = await _sut.GetByIdAsync(Guid.NewGuid());

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task CreateAsync_Should_CallRepository_When_InputIsValid()
        {
            // Arrange
            var request = new CreateProductRequest { Name = "New Widget", Price = 9.99m };

            // Act
            await _sut.CreateAsync(request);

            // Assert
            await _repository.Received(1).AddAsync(
                Arg.Is<Product>(p => p.Name == "New Widget"),
                Arg.Any<CancellationToken>()
            );
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("   ")]
        public async Task CreateAsync_Should_ThrowArgumentException_When_NameIsInvalid(string? name)
        {
            // Arrange
            var request = new CreateProductRequest { Name = name!, Price = 9.99m };

            // Act & Assert
            await Assert.ThrowsAsync<ArgumentException>(
                () => _sut.CreateAsync(request)
            );
        }
    }

## Step 2 — Frontend Unit Tests (Jest / Vitest)

Use this step when the target file is a TypeScript/JavaScript component (.tsx, .ts, .jsx).

### Test File Location

- **React**: Colocate test files next to the component
  - `components/ProductList.tsx` → `components/ProductList.test.tsx`
- **Angular**: Colocate test files next to the component
  - `product-list/product-list.component.ts` → `product-list/product-list.component.spec.ts`

### Test Structure Rules

- Use `describe` blocks to group tests by component or feature
- Use `it` or `test` for individual test cases
- Use `beforeEach` for shared setup
- Use `afterEach` with `cleanup()` to prevent test pollution
- Prefer `userEvent` over `fireEvent` for user interactions

### Testing Library Query Priority

Use queries in this priority order (most accessible first):

1. `getByRole` — Accessible role queries (BEST)
2. `getByLabelText` — Form elements
3. `getByPlaceholderText` — Input placeholders
4. `getByText` — Visible text content
5. `getByDisplayValue` — Current form values
6. `getByTestId` — LAST RESORT only

### What to Test

For each component, generate tests for:

1. **Renders correctly** — Component mounts without errors
2. **Displays data** — Data from props/state renders in the DOM
3. **User interactions** — Click, type, select triggers correct behavior
4. **Loading state** — Shows loading indicator while fetching
5. **Empty state** — Shows appropriate message when no data
6. **Error state** — Shows error message when API fails
7. **Conditional rendering** — Elements show/hide based on state
8. **Form validation** — Invalid input shows error messages
9. **Navigation** — Links and buttons navigate correctly

### React Test Example Pattern

    import { render, screen, waitFor } from '@testing-library/react';
    import userEvent from '@testing-library/user-event';
    import { ProductList } from './ProductList';
    import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

    // Mock the API hook
    vi.mock('../hooks/useProducts', () => ({
      useProducts: vi.fn(),
    }));

    import { useProducts } from '../hooks/useProducts';

    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });

    const renderWithProviders = (ui: React.ReactElement) =>
      render(
        <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>
      );

    describe('ProductList', () => {
      beforeEach(() => {
        vi.clearAllMocks();
      });

      it('should render loading state initially', () => {
        (useProducts as ReturnType<typeof vi.fn>).mockReturnValue({
          data: undefined,
          isLoading: true,
          error: null,
        });

        renderWithProviders(<ProductList />);

        expect(screen.getByRole('progressbar')).toBeInTheDocument();
      });

      it('should render products when data is loaded', () => {
        (useProducts as ReturnType<typeof vi.fn>).mockReturnValue({
          data: [
            { id: '1', name: 'Widget', price: 9.99 },
            { id: '2', name: 'Gadget', price: 19.99 },
          ],
          isLoading: false,
          error: null,
        });

        renderWithProviders(<ProductList />);

        expect(screen.getByText('Widget')).toBeInTheDocument();
        expect(screen.getByText('Gadget')).toBeInTheDocument();
      });

      it('should show empty state when no products exist', () => {
        (useProducts as ReturnType<typeof vi.fn>).mockReturnValue({
          data: [],
          isLoading: false,
          error: null,
        });

        renderWithProviders(<ProductList />);

        expect(screen.getByText(/no products found/i)).toBeInTheDocument();
      });

      it('should show error message when API fails', () => {
        (useProducts as ReturnType<typeof vi.fn>).mockReturnValue({
          data: undefined,
          isLoading: false,
          error: new Error('Failed to fetch'),
        });

        renderWithProviders(<ProductList />);

        expect(screen.getByRole('alert')).toBeInTheDocument();
      });

      it('should navigate to product detail on row click', async () => {
        const user = userEvent.setup();

        (useProducts as ReturnType<typeof vi.fn>).mockReturnValue({
          data: [{ id: '1', name: 'Widget', price: 9.99 }],
          isLoading: false,
          error: null,
        });

        renderWithProviders(<ProductList />);

        await user.click(screen.getByText('Widget'));

        // Assert navigation occurred
      });
    });

### Angular Test Example Pattern

    import { ComponentFixture, TestBed } from '@angular/core/testing';
    import { provideHttpClientTesting } from '@angular/common/http/testing';
    import { ProductListComponent } from './product-list.component';
    import { ProductService } from '../../services/product.service';
    import { of, throwError } from 'rxjs';
    import { signal } from '@angular/core';

    describe('ProductListComponent', () => {
      let component: ProductListComponent;
      let fixture: ComponentFixture<ProductListComponent>;
      let productService: jasmine.SpyObj<ProductService>;

      beforeEach(async () => {
        const spy = jasmine.createSpyObj('ProductService', ['getAll']);

        await TestBed.configureTestingModule({
          imports: [ProductListComponent],
          providers: [
            { provide: ProductService, useValue: spy },
            provideHttpClientTesting(),
          ],
        }).compileComponents();

        productService = TestBed.inject(ProductService) as jasmine.SpyObj<ProductService>;
        fixture = TestBed.createComponent(ProductListComponent);
        component = fixture.componentInstance;
      });

      it('should create', () => {
        expect(component).toBeTruthy();
      });

      it('should display products when loaded', () => {
        productService.getAll.and.returnValue(of([
          { id: '1', name: 'Widget', price: 9.99 },
        ]));

        fixture.detectChanges();

        const compiled = fixture.nativeElement as HTMLElement;
        expect(compiled.querySelector('.product-name')?.textContent)
          .toContain('Widget');
      });

      it('should show empty state when no products', () => {
        productService.getAll.and.returnValue(of([]));

        fixture.detectChanges();

        const compiled = fixture.nativeElement as HTMLElement;
        expect(compiled.querySelector('.empty-state')).toBeTruthy();
      });

      it('should show error when service fails', () => {
        productService.getAll.and.returnValue(
          throwError(() => new Error('API error'))
        );

        fixture.detectChanges();

        const compiled = fixture.nativeElement as HTMLElement;
        expect(compiled.querySelector('[role="alert"]')).toBeTruthy();
      });
    });

## Step 3 — Integration Tests (When Requested)

If the developer asks for integration tests, generate tests using WebApplicationFactory
and Testcontainers.

### Integration Test Rules

- Use `WebApplicationFactory<Program>` to spin up the API in-memory
- Use **Testcontainers** for real database testing (PostgreSQL or SQL Server)
- NEVER mock the database in integration tests — use a real containerized instance
- Test the full HTTP request/response cycle
- Include authentication setup using test tokens

### Integration Test Example Pattern

    using Microsoft.AspNetCore.Mvc.Testing;
    using System.Net;
    using System.Net.Http.Json;
    using Testcontainers.PostgreSql;

    namespace MyApp.Tests.Integration.Api;

    public sealed class ProductApiTests : IClassFixture<CustomWebApplicationFactory>, IAsyncLifetime
    {
        private readonly HttpClient _client;
        private readonly CustomWebApplicationFactory _factory;

        public ProductApiTests(CustomWebApplicationFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        public Task InitializeAsync() => Task.CompletedTask;
        public Task DisposeAsync() => Task.CompletedTask;

        [Fact]
        public async Task GetProducts_Should_Return200_With_EmptyList()
        {
            // Act
            var response = await _client.GetAsync("/api/v1/products");

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            var products = await response.Content.ReadFromJsonAsync<List<ProductResponse>>();
            Assert.NotNull(products);
            Assert.Empty(products);
        }

        [Fact]
        public async Task CreateProduct_Should_Return201_When_Valid()
        {
            // Arrange
            var request = new CreateProductRequest
            {
                Name = "Integration Test Widget",
                Price = 29.99m
            };

            // Act
            var response = await _client.PostAsJsonAsync("/api/v1/products", request);

            // Assert
            Assert.Equal(HttpStatusCode.Created, response.StatusCode);

            var created = await response.Content.ReadFromJsonAsync<ProductResponse>();
            Assert.NotNull(created);
            Assert.Equal(request.Name, created.Name);
            Assert.NotEqual(Guid.Empty, created.Id);
        }

        [Fact]
        public async Task CreateProduct_Should_Return400_When_NameIsEmpty()
        {
            // Arrange
            var request = new CreateProductRequest { Name = "", Price = 0 };

            // Act
            var response = await _client.PostAsJsonAsync("/api/v1/products", request);

            // Assert
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task GetProduct_Should_Return404_When_NotFound()
        {
            // Act
            var response = await _client.GetAsync($"/api/v1/products/{Guid.NewGuid()}");

            // Assert
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }
    }

## Step 4 — Verify Test Coverage

After generating tests, remind the developer to check coverage:

### Backend Coverage

    dotnet test --collect:"XPlat Code Coverage"
    reportgenerator -reports:**/coverage.cobertura.xml -targetdir:coverage-report

Coverage targets per constitution:

- Business logic / Application layer: minimum 80%
- Controllers / Endpoints: integration tests cover these
- Domain entities: covered if they contain behavior

### Frontend Coverage

    # Jest
    npx jest --coverage

    # Vitest
    npx vitest run --coverage

Coverage targets per constitution:

- Components with business logic: minimum 70%
- Utility functions: minimum 80%
- API service layers: minimum 80%

## Reminders

- Test names MUST be descriptive — someone reading only the test name should understand what is being verified
- Each test MUST test ONE behavior — no multi-assertion tests that test unrelated things
- Tests MUST be independent — no test should depend on another test running first
- Tests MUST be deterministic — no random values, timestamps, or external dependencies
- Use [Theory] with [InlineData] for parameterized tests when testing multiple inputs
- Use [Fact] for single-scenario tests
- Mock external dependencies, not internal logic
- Prefer testing behavior over implementation details
- For frontend: test what the user sees, not component internals
- Run the full test suite before committing to ensure no regressions
- Keep test files organized matching the source code folder structure
