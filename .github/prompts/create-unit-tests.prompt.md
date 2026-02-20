---
agent: agent
description: "Generate comprehensive xUnit unit tests for a C# class following org standards"
---

# Create Unit Tests

Generate comprehensive xUnit unit tests for the selected class or the class described below.
Follow ALL standards from `.specify/memory/constitution.md` and `.github/instructions/xunit-testing.instructions.md`.

## Target

- **Class to test**: ${input:className:What class do you want to test? (e.g., UserService, CreateUserRequestValidator)}
- **Test type**: ${input:testType:What type of tests? (unit, integration, both):unit}

## Instructions

### Analyze the Target Class

1. Read the selected class or find the class by name in the workspace
2. Identify ALL public methods
3. Identify constructor dependencies (these become mocks)
4. Identify return types, parameters, and possible outcomes for each method
5. Identify validation logic, branching paths, and error scenarios

### Generate Test Class Structure

Create a test class following this pattern:

- File name: `{ClassName}Tests.cs`
- Class name: `{ClassName}Tests`
- Use `sealed` modifier on the test class
- Name the system under test `_sut`
- Create private fields for all mocked dependencies
- Initialize `_sut` and all mocks in the constructor
- Use NSubstitute for all interface mocking: `Substitute.For<T>()`

### Generate Tests for Each Public Method

For each public method, generate tests covering:

**Happy Path Tests**:

- Method succeeds with valid input
- Method returns expected data type and values
- Method calls expected dependencies

**Not Found / Null Tests**:

- Method receives ID that does not exist → returns null or appropriate response
- Method receives null parameters → throws or handles gracefully

**Validation / Error Tests**:

- Method receives invalid input (empty strings, invalid formats, out of range values)
- Method receives duplicate data (unique constraint violations)
- Method encounters expected business rule failures

**Edge Case Tests**:

- Method receives boundary values (max length strings, zero, negative numbers)
- Method receives empty collections
- Method handles concurrent scenarios (if applicable)

### Test Method Requirements

For EVERY test method:

1. Name: `MethodName_Should_ExpectedBehavior_When_Condition`
2. Use `[Fact]` for single-case tests
3. Use `[Theory]` with `[InlineData]` for parameterized tests (invalid inputs, boundary values)
4. Use `[Theory]` with `[MemberData]` for complex test data
5. Use Arrange-Act-Assert (AAA) pattern with comment markers:

   // Arrange
   (setup mocks and test data)

   // Act
   (call the method under test)

   // Assert
   (verify the result)

6. Include `CancellationToken.None` in all async method calls
7. Make test methods `async Task` (not `async void`)
8. One assertion concept per test (multiple Assert calls for the same concept is OK)

### Mock Setup Requirements

- Use `Arg.Any<T>()` for parameters you do not care about
- Use `Arg.Is<T>(predicate)` for condition-based matching
- Use `.Returns()` for setting up return values
- Use `.ThrowsAsync()` for setting up exception scenarios
- Use `.Received(n)` to verify method calls
- Use `.DidNotReceive()` to verify method was NOT called
- Always include `Arg.Any<CancellationToken>()` for async mock setups

### IDbContextFactory Mocking

If the class under test uses `IDbContextFactory<AppDbContext>`:

- Mock the factory: `Substitute.For<IDbContextFactory<AppDbContext>>()`
- For simple tests, create an in-memory DbContext or mock the DbContext
- Setup: `factory.CreateDbContextAsync(Arg.Any<CancellationToken>()).Returns(mockDbContext)`
- Consider using a helper method to create test DbContext with seeded data

### Test Data

- Use meaningful test data (not "test", "abc", or "123")
- Use realistic emails: "alice.johnson@example.com"
- Use realistic names: "Alice Johnson"
- Use `Guid.NewGuid()` for IDs
- Use `DateTimeOffset.UtcNow` for timestamps
- Consider creating a Test Data Builder if the class has complex setup

### Validator Tests (if target is a FluentValidation validator)

Generate tests that verify:

- Valid input passes validation (result.IsValid is true)
- Each required field fails when empty
- Each field with max length fails when exceeded
- Each field with format requirements fails with invalid format
- Multiple invalid fields produce multiple errors
- Check specific error messages and property names

### What NOT to Generate

- Do NOT test private methods — test through the public API
- Do NOT test EF Core itself (generated SQL, migrations)
- Do NOT test framework code (ASP.NET Core middleware, DI container)
- Do NOT test third-party libraries
- Do NOT create tests that depend on external services

### Output

Generate a COMPLETE test file including:

- All required `using` statements
- Test class with constructor setup
- ALL test methods (aim for at least 8-15 tests per service class)
- Any helper methods needed (mock setup, test data builders)

Also show the NuGet packages needed if not already installed:

    xunit
    xunit.runner.visualstudio
    Microsoft.NET.Test.Sdk
    NSubstitute
    NSubstitute.Analyzers.CSharp
    coverlet.collector
