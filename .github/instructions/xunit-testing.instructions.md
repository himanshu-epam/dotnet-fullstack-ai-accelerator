---
applyTo: "tests/**/*.cs,**/*Tests.cs,**/*Test.cs,**/*.Tests/**,**/*.Tests.Unit/**,**/*.Tests.Integration/**"
---

# xUnit Testing Instructions

## Overview

- Framework: **xUnit** (no MSTest or NUnit)
- Mocking: **NSubstitute** (preferred) or Moq
- Assertions: **xUnit built-in assertions** preferred, FluentAssertions acceptable
- Integration tests: **WebApplicationFactory** + **Testcontainers**
- Minimum **80% code coverage** for business logic / application layer
- Test naming: `MethodName_Should_ExpectedBehavior_When_Condition`
- Pattern: **Arrange-Act-Assert (AAA)** with comment markers

## Unit Test Class Structure

    public sealed class UserServiceTests
    {
        private readonly IDbContextFactory<AppDbContext> _dbContextFactory;
        private readonly ILogger<UserService> _logger;
        private readonly UserService _sut;

        public UserServiceTests()
        {
            _dbContextFactory = Substitute.For<IDbContextFactory<AppDbContext>>();
            _logger = Substitute.For<ILogger<UserService>>();
            _sut = new UserService(_dbContextFactory, _logger);
        }
    }

Key conventions:

- `_sut` is always the System Under Test
- Private fields for all mocked dependencies
- Constructor sets up the SUT and its dependencies
- Each test method is independent — no shared state between tests
- Use `sealed` on test classes

---

## [Fact] Test Pattern — Single Case

    [Fact]
    public async Task GetByIdAsync_Should_ReturnUser_When_UserExists()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var expected = new User
        {
            Id = userId,
            Email = "test@example.com",
            DisplayName = "Test User",
            CreatedAt = DateTimeOffset.UtcNow
        };

        var mockDbContext = CreateMockDbContext(new List<User> { expected });
        _dbContextFactory
            .CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(mockDbContext);

        // Act
        var result = await _sut.GetByIdAsync(userId, CancellationToken.None);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(expected.Email, result.Email);
        Assert.Equal(expected.DisplayName, result.DisplayName);
    }

    [Fact]
    public async Task GetByIdAsync_Should_ReturnNull_When_UserNotFound()
    {
        // Arrange
        var mockDbContext = CreateMockDbContext(new List<User>());
        _dbContextFactory
            .CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(mockDbContext);

        // Act
        var result = await _sut.GetByIdAsync(Guid.NewGuid(), CancellationToken.None);

        // Assert
        Assert.Null(result);
    }

    [Fact]
    public async Task CreateAsync_Should_ReturnCreatedUser_When_InputIsValid()
    {
        // Arrange
        var request = new CreateUserRequest("john@example.com", "John Doe");
        var mockDbContext = CreateMockDbContext(new List<User>());
        _dbContextFactory
            .CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(mockDbContext);

        // Act
        var result = await _sut.CreateAsync(request, CancellationToken.None);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(request.Email, result.Email);
        Assert.Equal(request.DisplayName, result.DisplayName);
        Assert.NotEqual(Guid.Empty, result.Id);
    }

    [Fact]
    public async Task DeleteAsync_Should_ReturnTrue_When_UserExists()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var existingUser = new User
        {
            Id = userId,
            Email = "delete@example.com",
            DisplayName = "Delete Me"
        };

        var mockDbContext = CreateMockDbContext(new List<User> { existingUser });
        _dbContextFactory
            .CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(mockDbContext);

        // Act
        var result = await _sut.DeleteAsync(userId, CancellationToken.None);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task DeleteAsync_Should_ReturnFalse_When_UserNotFound()
    {
        // Arrange
        var mockDbContext = CreateMockDbContext(new List<User>());
        _dbContextFactory
            .CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(mockDbContext);

        // Act
        var result = await _sut.DeleteAsync(Guid.NewGuid(), CancellationToken.None);

        // Assert
        Assert.False(result);
    }

---

## [Theory] Test Pattern — Parameterized

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData(null)]
    public async Task CreateAsync_Should_ThrowValidationException_When_EmailIsInvalid(
        string? email)
    {
        // Arrange
        var request = new CreateUserRequest(email!, "Test User");

        // Act & Assert
        await Assert.ThrowsAsync<ValidationException>(
            () => _sut.CreateAsync(request, CancellationToken.None));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-100)]
    public async Task GetAllAsync_Should_ThrowArgumentException_When_PageIsInvalid(
        int invalidPage)
    {
        // Arrange & Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(
            () => _sut.GetAllAsync(invalidPage, 20, CancellationToken.None));
    }

    [Theory]
    [InlineData(1, 10, 25, 3)]
    [InlineData(1, 20, 25, 2)]
    [InlineData(1, 50, 25, 1)]
    [InlineData(2, 10, 25, 3)]
    public async Task GetAllAsync_Should_ReturnCorrectTotalPages_When_VariousPageSizes(
        int page, int pageSize, int totalItems, int expectedTotalPages)
    {
        // Arrange
        var users = Enumerable.Range(1, totalItems)
            .Select(i => new User
            {
                Id = Guid.NewGuid(),
                Email = $"user{i}@example.com",
                DisplayName = $"User {i}",
                CreatedAt = DateTimeOffset.UtcNow
            })
            .ToList();

        var mockDbContext = CreateMockDbContext(users);
        _dbContextFactory
            .CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(mockDbContext);

        // Act
        var result = await _sut.GetAllAsync(page, pageSize, CancellationToken.None);

        // Assert
        Assert.Equal(totalItems, result.TotalCount);
        Assert.Equal(expectedTotalPages, result.TotalPages);
    }

---

## [MemberData] Pattern — Complex Test Data

Use MemberData when test data is too complex for InlineData:

    public sealed class UserServiceTests
    {
        public static IEnumerable<object[]> InvalidCreateRequests =>
            new List<object[]>
            {
                new object[] { new CreateUserRequest("", "Valid Name"), "Email is required" },
                new object[] { new CreateUserRequest("not-an-email", "Valid Name"), "Email format is invalid" },
                new object[] { new CreateUserRequest("valid@email.com", ""), "Display name is required" },
                new object[] { new CreateUserRequest("valid@email.com", new string('A', 101)), "Display name too long" },
            };

        [Theory]
        [MemberData(nameof(InvalidCreateRequests))]
        public async Task CreateAsync_Should_ThrowValidationException_When_RequestIsInvalid(
            CreateUserRequest request, string expectedError)
        {
            // Arrange & Act
            var exception = await Assert.ThrowsAsync<ValidationException>(
                () => _sut.CreateAsync(request, CancellationToken.None));

            // Assert
            Assert.Contains(expectedError, exception.Message);
        }
    }

---

## [ClassData] Pattern — Shared Test Data Across Classes

    public sealed class InvalidEmailTestData : IEnumerable<object[]>
    {
        public IEnumerator<object[]> GetEnumerator()
        {
            yield return new object[] { "" };
            yield return new object[] { " " };
            yield return new object[] { "not-an-email" };
            yield return new object[] { "@missing-local.com" };
            yield return new object[] { "missing-domain@" };
            yield return new object[] { "spaces in@email.com" };
        }

        IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
    }

    [Theory]
    [ClassData(typeof(InvalidEmailTestData))]
    public async Task CreateAsync_Should_ThrowValidationException_When_EmailFormatIsInvalid(
        string invalidEmail)
    {
        // Arrange
        var request = new CreateUserRequest(invalidEmail, "Valid Name");

        // Act & Assert
        await Assert.ThrowsAsync<ValidationException>(
            () => _sut.CreateAsync(request, CancellationToken.None));
    }

---

## NSubstitute Mocking Patterns

### Basic Mock Setup

    var userService = Substitute.For<IUserService>();

    // Return a specific value
    userService
        .GetByIdAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>())
        .Returns(new UserResponse(
            Guid.NewGuid(),
            "test@example.com",
            "Test User",
            DateTimeOffset.UtcNow,
            null));

    // Return null
    userService
        .GetByIdAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>())
        .Returns((UserResponse?)null);

    // Throw exception
    userService
        .CreateAsync(Arg.Any<CreateUserRequest>(), Arg.Any<CancellationToken>())
        .ThrowsAsync(new ValidationException("Email already exists"));

### Argument Matching

    // Any value
    userService.GetByIdAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>());

    // Specific value
    var specificId = Guid.Parse("12345678-1234-1234-1234-123456789012");
    userService.GetByIdAsync(specificId, Arg.Any<CancellationToken>());

    // Condition-based
    userService.GetByIdAsync(
        Arg.Is<Guid>(id => id != Guid.Empty),
        Arg.Any<CancellationToken>());

### Verify Calls

    // Verify method was called
    await userService.Received(1)
        .CreateAsync(Arg.Any<CreateUserRequest>(), Arg.Any<CancellationToken>());

    // Verify method was NOT called
    await userService.DidNotReceive()
        .DeleteAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>());

    // Verify with specific arguments
    await userService.Received(1)
        .CreateAsync(
            Arg.Is<CreateUserRequest>(r => r.Email == "test@example.com"),
            Arg.Any<CancellationToken>());

### Mock ILogger (Verify Logging)

    var logger = Substitute.For<ILogger<UserService>>();

    // After running the test, verify a log was written
    logger.Received(1).Log(
        LogLevel.Information,
        Arg.Any<EventId>(),
        Arg.Is<object>(o => o.ToString()!.Contains("Created user")),
        Arg.Any<Exception?>(),
        Arg.Any<Func<object, Exception?, string>>());

---

## FluentValidation Validator Testing

    public sealed class CreateUserRequestValidatorTests
    {
        private readonly CreateUserRequestValidator _validator = new();

        [Fact]
        public void Validate_Should_Pass_When_RequestIsValid()
        {
            // Arrange
            var request = new CreateUserRequest("valid@example.com", "Valid Name");

            // Act
            var result = _validator.Validate(request);

            // Assert
            Assert.True(result.IsValid);
            Assert.Empty(result.Errors);
        }

        [Fact]
        public void Validate_Should_Fail_When_EmailIsEmpty()
        {
            // Arrange
            var request = new CreateUserRequest("", "Valid Name");

            // Act
            var result = _validator.Validate(request);

            // Assert
            Assert.False(result.IsValid);
            Assert.Contains(result.Errors, e => e.PropertyName == "Email");
        }

        [Fact]
        public void Validate_Should_Fail_When_EmailFormatIsInvalid()
        {
            // Arrange
            var request = new CreateUserRequest("not-an-email", "Valid Name");

            // Act
            var result = _validator.Validate(request);

            // Assert
            Assert.False(result.IsValid);
            Assert.Contains(result.Errors, e =>
                e.PropertyName == "Email" &&
                e.ErrorMessage.Contains("valid email"));
        }

        [Fact]
        public void Validate_Should_Fail_When_DisplayNameExceedsMaxLength()
        {
            // Arrange
            var request = new CreateUserRequest("valid@example.com", new string('A', 101));

            // Act
            var result = _validator.Validate(request);

            // Assert
            Assert.False(result.IsValid);
            Assert.Contains(result.Errors, e => e.PropertyName == "DisplayName");
        }

        [Fact]
        public void Validate_Should_Fail_When_MultipleFieldsAreInvalid()
        {
            // Arrange
            var request = new CreateUserRequest("", "");

            // Act
            var result = _validator.Validate(request);

            // Assert
            Assert.False(result.IsValid);
            Assert.True(result.Errors.Count >= 2);
            Assert.Contains(result.Errors, e => e.PropertyName == "Email");
            Assert.Contains(result.Errors, e => e.PropertyName == "DisplayName");
        }
    }

---

## Integration Test Pattern with WebApplicationFactory

### Custom WebApplicationFactory

    public sealed class CustomWebApplicationFactory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureTestServices(services =>
            {
                // Replace real auth with test auth
                services.AddAuthentication(TestAuthHandler.SchemeName)
                    .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                        TestAuthHandler.SchemeName, _ => { });

                // Replace real database with Testcontainers
                // (see Testcontainers section below)
            });

            builder.UseEnvironment("Testing");
        }
    }

### Integration Test Class

    public sealed class UsersApiTests : IClassFixture<CustomWebApplicationFactory>, IAsyncLifetime
    {
        private readonly CustomWebApplicationFactory _factory;
        private readonly HttpClient _client;

        public UsersApiTests(CustomWebApplicationFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        public Task InitializeAsync() => Task.CompletedTask;
        public Task DisposeAsync() => Task.CompletedTask;

        [Fact]
        public async Task GetAll_Should_Return200_When_Authenticated()
        {
            // Arrange & Act
            var response = await _client.GetAsync("/api/v1/users?page=1&pageSize=10");

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            var content = await response.Content.ReadFromJsonAsync<PagedResult<UserResponse>>();
            Assert.NotNull(content);
            Assert.True(content.Page >= 1);
        }

        [Fact]
        public async Task GetById_Should_Return404_When_UserNotFound()
        {
            // Arrange
            var nonExistentId = Guid.NewGuid();

            // Act
            var response = await _client.GetAsync($"/api/v1/users/{nonExistentId}");

            // Assert
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }

        [Fact]
        public async Task Create_Should_Return201_When_InputIsValid()
        {
            // Arrange
            var request = new CreateUserRequest("integration@example.com", "Integration User");

            // Act
            var response = await _client.PostAsJsonAsync("/api/v1/users", request);

            // Assert
            Assert.Equal(HttpStatusCode.Created, response.StatusCode);
            Assert.NotNull(response.Headers.Location);

            var created = await response.Content.ReadFromJsonAsync<UserResponse>();
            Assert.NotNull(created);
            Assert.Equal(request.Email, created.Email);
            Assert.NotEqual(Guid.Empty, created.Id);
        }

        [Fact]
        public async Task Create_Should_Return400_When_EmailIsEmpty()
        {
            // Arrange
            var request = new CreateUserRequest("", "Valid Name");

            // Act
            var response = await _client.PostAsJsonAsync("/api/v1/users", request);

            // Assert
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task Create_Should_Return409_When_EmailAlreadyExists()
        {
            // Arrange
            var request = new CreateUserRequest("duplicate@example.com", "First User");
            await _client.PostAsJsonAsync("/api/v1/users", request);

            var duplicateRequest = new CreateUserRequest("duplicate@example.com", "Second User");

            // Act
            var response = await _client.PostAsJsonAsync("/api/v1/users", duplicateRequest);

            // Assert
            Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        }

        [Fact]
        public async Task Update_Should_Return200_When_UserExistsAndInputIsValid()
        {
            // Arrange — create a user first
            var createRequest = new CreateUserRequest("update@example.com", "Before Update");
            var createResponse = await _client.PostAsJsonAsync("/api/v1/users", createRequest);
            var created = await createResponse.Content.ReadFromJsonAsync<UserResponse>();

            var updateRequest = new UpdateUserRequest("After Update");

            // Act
            var response = await _client.PutAsJsonAsync($"/api/v1/users/{created!.Id}", updateRequest);

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            var updated = await response.Content.ReadFromJsonAsync<UserResponse>();
            Assert.NotNull(updated);
            Assert.Equal("After Update", updated.DisplayName);
            Assert.NotNull(updated.UpdatedAt);
        }

        [Fact]
        public async Task Delete_Should_Return204_When_UserExists()
        {
            // Arrange — create a user first
            var createRequest = new CreateUserRequest("delete@example.com", "Delete Me");
            var createResponse = await _client.PostAsJsonAsync("/api/v1/users", createRequest);
            var created = await createResponse.Content.ReadFromJsonAsync<UserResponse>();

            // Act
            var response = await _client.DeleteAsync($"/api/v1/users/{created!.Id}");

            // Assert
            Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

            // Verify it's actually deleted
            var getResponse = await _client.GetAsync($"/api/v1/users/{created.Id}");
            Assert.Equal(HttpStatusCode.NotFound, getResponse.StatusCode);
        }
    }

---

## Testcontainers Pattern — Real Database in Integration Tests

### PostgreSQL Testcontainer

    public sealed class PostgresWebApplicationFactory : WebApplicationFactory<Program>, IAsyncLifetime
    {
        private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .WithDatabase("testdb")
            .WithUsername("postgres")
            .WithPassword("testpassword")
            .Build();

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureTestServices(services =>
            {
                // Remove existing DbContextFactory registration
                var descriptor = services.SingleOrDefault(
                    d => d.ServiceType == typeof(IDbContextFactory<AppDbContext>));
                if (descriptor is not null)
                {
                    services.Remove(descriptor);
                }

                // Also remove DbContextOptions
                var optionsDescriptor = services.SingleOrDefault(
                    d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
                if (optionsDescriptor is not null)
                {
                    services.Remove(optionsDescriptor);
                }

                // Register with Testcontainers connection string
                services.AddDbContextFactory<AppDbContext>(options =>
                    options.UseNpgsql(_postgres.GetConnectionString()));

                // Replace auth with test auth
                services.AddAuthentication(TestAuthHandler.SchemeName)
                    .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                        TestAuthHandler.SchemeName, _ => { });
            });

            builder.UseEnvironment("Testing");
        }

        public async Task InitializeAsync()
        {
            await _postgres.StartAsync();

            // Apply migrations to test database
            using var scope = Services.CreateScope();
            var dbContextFactory = scope.ServiceProvider
                .GetRequiredService<IDbContextFactory<AppDbContext>>();
            await using var dbContext = await dbContextFactory.CreateDbContextAsync();
            await dbContext.Database.MigrateAsync();
        }

        public new async Task DisposeAsync()
        {
            await _postgres.DisposeAsync();
            await base.DisposeAsync();
        }
    }

### SQL Server Testcontainer

    public sealed class SqlServerWebApplicationFactory : WebApplicationFactory<Program>, IAsyncLifetime
    {
        private readonly MsSqlContainer _sqlServer = new MsSqlBuilder()
            .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
            .WithPassword("YourStrong!Password123")
            .Build();

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureTestServices(services =>
            {
                var descriptor = services.SingleOrDefault(
                    d => d.ServiceType == typeof(IDbContextFactory<AppDbContext>));
                if (descriptor is not null)
                {
                    services.Remove(descriptor);
                }

                var optionsDescriptor = services.SingleOrDefault(
                    d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
                if (optionsDescriptor is not null)
                {
                    services.Remove(optionsDescriptor);
                }

                services.AddDbContextFactory<AppDbContext>(options =>
                    options.UseSqlServer(_sqlServer.GetConnectionString()));

                services.AddAuthentication(TestAuthHandler.SchemeName)
                    .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                        TestAuthHandler.SchemeName, _ => { });
            });

            builder.UseEnvironment("Testing");
        }

        public async Task InitializeAsync()
        {
            await _sqlServer.StartAsync();

            using var scope = Services.CreateScope();
            var dbContextFactory = scope.ServiceProvider
                .GetRequiredService<IDbContextFactory<AppDbContext>>();
            await using var dbContext = await dbContextFactory.CreateDbContextAsync();
            await dbContext.Database.MigrateAsync();
        }

        public new async Task DisposeAsync()
        {
            await _sqlServer.DisposeAsync();
            await base.DisposeAsync();
        }
    }

### Using Testcontainers in Tests

    public sealed class UsersApiIntegrationTests
        : IClassFixture<PostgresWebApplicationFactory>
    {
        private readonly HttpClient _client;

        public UsersApiIntegrationTests(PostgresWebApplicationFactory factory)
        {
            _client = factory.CreateClient();
        }

        [Fact]
        public async Task FullCrudLifecycle_Should_WorkEndToEnd()
        {
            // Create
            var createRequest = new CreateUserRequest("crud@example.com", "CRUD User");
            var createResponse = await _client.PostAsJsonAsync("/api/v1/users", createRequest);
            Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);
            var created = await createResponse.Content.ReadFromJsonAsync<UserResponse>();

            // Read
            var getResponse = await _client.GetAsync($"/api/v1/users/{created!.Id}");
            Assert.Equal(HttpStatusCode.OK, getResponse.StatusCode);

            // Update
            var updateRequest = new UpdateUserRequest("Updated CRUD User");
            var updateResponse = await _client.PutAsJsonAsync(
                $"/api/v1/users/{created.Id}", updateRequest);
            Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

            // Delete
            var deleteResponse = await _client.DeleteAsync($"/api/v1/users/{created.Id}");
            Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);

            // Verify deleted
            var verifyResponse = await _client.GetAsync($"/api/v1/users/{created.Id}");
            Assert.Equal(HttpStatusCode.NotFound, verifyResponse.StatusCode);
        }
    }

---

## Test Utilities

### Test Data Builder Pattern

    public sealed class UserBuilder
    {
        private Guid _id = Guid.NewGuid();
        private string _email = "default@example.com";
        private string _displayName = "Default User";
        private bool _isActive = true;
        private DateTimeOffset _createdAt = DateTimeOffset.UtcNow;

        public UserBuilder WithId(Guid id) { _id = id; return this; }
        public UserBuilder WithEmail(string email) { _email = email; return this; }
        public UserBuilder WithDisplayName(string name) { _displayName = name; return this; }
        public UserBuilder WithIsActive(bool active) { _isActive = active; return this; }
        public UserBuilder WithCreatedAt(DateTimeOffset date) { _createdAt = date; return this; }

        public User Build() => new()
        {
            Id = _id,
            Email = _email,
            DisplayName = _displayName,
            IsActive = _isActive,
            CreatedAt = _createdAt
        };
    }

    // Usage in tests
    var user = new UserBuilder()
        .WithEmail("custom@example.com")
        .WithDisplayName("Custom User")
        .Build();

---

## Test Project Organization

    tests/
    ├── MyApp.Tests.Unit/
    │   ├── MyApp.Tests.Unit.csproj
    │   ├── Services/
    │   │   ├── UserServiceTests.cs
    │   │   └── ProjectServiceTests.cs
    │   ├── Validators/
    │   │   ├── CreateUserRequestValidatorTests.cs
    │   │   └── UpdateUserRequestValidatorTests.cs
    │   ├── Extensions/
    │   │   └── ClaimsPrincipalExtensionsTests.cs
    │   └── Builders/
    │       └── UserBuilder.cs
    ├── MyApp.Tests.Integration/
    │   ├── MyApp.Tests.Integration.csproj
    │   ├── Fixtures/
    │   │   ├── PostgresWebApplicationFactory.cs
    │   │   └── TestAuthHandler.cs
    │   ├── Api/
    │   │   ├── UsersApiTests.cs
    │   │   └── ProjectsApiTests.cs
    │   └── Data/
    │       └── UserRepositoryTests.cs
    └── MyApp.Tests.Architecture/  (optional)
        └── ArchitectureTests.cs

---

## NuGet Packages for Test Projects

Unit test project:

    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
    <PackageReference Include="NSubstitute" />
    <PackageReference Include="NSubstitute.Analyzers.CSharp" />
    <PackageReference Include="coverlet.collector" />

Integration test project (add these on top of unit test packages):

    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" />
    <PackageReference Include="Testcontainers.PostgreSql" />
    <!-- or for SQL Server -->
    <PackageReference Include="Testcontainers.MsSql" />

---

## Rules Summary

### Naming Rules

1. Test class name: `{ClassUnderTest}Tests` (e.g., UserServiceTests)
2. Test method name: `MethodName_Should_ExpectedBehavior_When_Condition`
3. Test project name: `{ProjectName}.Tests.Unit` or `{ProjectName}.Tests.Integration`
4. Test file location mirrors source file location

### Structure Rules

5. ALWAYS use Arrange-Act-Assert (AAA) pattern with comment markers
6. ALWAYS use `sealed` on test classes
7. ALWAYS name the system under test `_sut`
8. ALWAYS create fresh mocks in the constructor — no shared state between tests
9. One assertion concept per test (multiple Assert calls for same concept is OK)

### Test Type Rules

10. Use `[Fact]` for single-case tests
11. Use `[Theory]` with `[InlineData]` for simple parameterized tests
12. Use `[Theory]` with `[MemberData]` for complex parameterized tests
13. Use `[Theory]` with `[ClassData]` for shared test data across classes

### Mocking Rules

14. ALWAYS use NSubstitute (Substitute.For) for mocking interfaces
15. ALWAYS include `Arg.Any<CancellationToken>()` when setting up async mocks
16. Use `Received(n)` to verify a method was called n times
17. Use `DidNotReceive()` to verify a method was NOT called
18. Use `Arg.Is<T>(predicate)` for condition-based argument matching

### Async Rules

19. ALWAYS make test methods async Task (not async void)
20. ALWAYS pass CancellationToken.None in test method calls
21. ALWAYS use await — never .Result or .Wait()

### Integration Test Rules

22. ALWAYS use WebApplicationFactory for API integration tests
23. ALWAYS use Testcontainers for real database in integration tests
24. ALWAYS replace auth with TestAuthHandler in integration tests
25. ALWAYS apply migrations in IAsyncLifetime.InitializeAsync
26. ALWAYS clean up containers in IAsyncLifetime.DisposeAsync
27. NEVER depend on external services — everything runs locally via containers

### Coverage Rules

28. Minimum 80% code coverage for business logic / application layer
29. Test happy paths AND error/edge cases for every public method
30. Test validation logic separately in validator test classes
31. Write integration tests for full CRUD lifecycle

### What NOT to Test

32. Do NOT test EF Core itself (generated SQL, migrations)
33. Do NOT test framework code (ASP.NET Core middleware, DI container)
34. Do NOT test third-party libraries
35. Do NOT test private methods — test through public API
