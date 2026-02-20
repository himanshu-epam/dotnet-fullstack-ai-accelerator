# ⚡ AI-Enabled Development in 5 Minutes

This guide walks you through enabling AI-assisted development in your existing or new .NET application.
By the end, your AI agent (Copilot, Cursor, Claude, Windsurf) will understand your entire tech stack
and coding standards — automatically.

---

## Prerequisites

Before you begin, make sure you have:

- [ ] An application using ASP.NET Core 8+ (or starting a new one)
- [ ] A Git repository for your application
- [ ] VS Code, Visual Studio 2022 (17.14+), or Cursor installed
- [ ] GitHub Copilot licensed (or another AI agent: Cursor, Claude Code, Windsurf)
- [ ] PowerShell 7+ (Windows) or Bash (Linux/macOS)

---

## Step 1: Add the Accelerator to Your Project (2 minutes)

You have three options. Pick the one that works best for your team.

### Option A: Git Submodule (Recommended)

This keeps the accelerator linked so you get updates automatically:

    cd your-project
    git submodule add <accelerator-repo-url> .ai-accelerator

### Option B: Direct Clone

If you just want a one-time copy:

    cd your-project
    git clone <accelerator-repo-url> .ai-accelerator

### Option C: Manual Copy

Download the accelerator repo as a ZIP and extract it into a `.ai-accelerator` folder
inside your project.

---

## Step 2: Run the Bootstrap Script (1 minute)

The bootstrap script copies all AI instructions, templates, and configurations into your project.

### PowerShell (Windows)

    .\.ai-accelerator\scaffold\init.ps1 `
      -TargetPath . `
      -Frontend angular `
      -Database postgres `
      -Agent all

### Bash (Linux / macOS)

    ./.ai-accelerator/scaffold/init.sh \
      --target . \
      --frontend angular \
      --database postgres \
      --agent all

### Parameters

| Parameter | Options | Default | Description |
|-----------|---------|---------|-------------|
| TargetPath / --target | Any valid path | (required) | Path to your application repo |
| Frontend / --frontend | `angular`, `react` | `angular` | Your frontend framework |
| Database / --database | `postgres`, `sqlserver` | `postgres` | Your database |
| Agent / --agent | `copilot`, `cursor`, `claude`, `windsurf`, `all` | `all` | Which AI agent(s) you use |

---

## Step 3: Open Your Project and Verify (1 minute)

Open your project in VS Code (or your preferred editor). The AI instructions load automatically.

### Verification Test

Open GitHub Copilot Chat (Ctrl+Shift+I in VS Code) and type:

    @workspace What coding standards and architectural principles does this project follow?

**Expected result:** Copilot should reference the constitution and mention things like:
- ASP.NET Core with Entity Framework Core
- Azure Entra ID authentication
- Scalar for API documentation
- xUnit for testing
- PostgreSQL or SQL Server
- Azure AKS deployment

If Copilot responds with generic advice instead of project-specific standards,
check that `.github/copilot-instructions.md` exists in your project root.

### Verification for Other Agents

| Agent | How to Verify |
|-------|--------------|
| **Cursor** | Open a `.cs` file, press Ctrl+K, ask "What patterns should I follow?" |
| **Claude Code** | Run `claude` in terminal, ask "What are the project standards?" |
| **Windsurf** | Open Cascade, ask "What tech stack does this project use?" |

---

## Step 4: Start Building with Spec-Driven Development (1 minute to start)

Now that AI understands your project, use the spec-driven workflow for any new feature:

### 1. Specify (Define WHAT)

Tell the AI what you want to build:

    Create a spec for: A new API endpoint for managing user profiles
    with CRUD operations, authenticated via Entra ID, stored in PostgreSQL,
    with full xUnit test coverage and an Angular UI component.

The AI will generate a structured spec using the template in `.specify/templates/spec-template.md`.

### 2. Plan (Define HOW)

Ask the AI to create a technical plan:

    Create an implementation plan for the user profiles feature spec.

The AI will generate a plan referencing the constitution and your tech stack.

### 3. Tasks (Break it down)

Ask the AI to break the plan into tasks:

    Break down the user profiles implementation plan into tasks.

The AI will generate parallelizable, ordered tasks.

### 4. Implement (Build it)

Execute tasks one by one with AI assistance. The AI already knows your patterns.

---

## 📂 What Was Installed in Your Project

Here is what the bootstrap script added to your project:

### Core Files (Always Installed)

| File | Purpose |
|------|---------|
| `.specify/memory/constitution.md` | Organization standards — the single source of truth |
| `.specify/templates/spec-template.md` | Template for feature specifications |
| `.specify/templates/plan-template.md` | Template for implementation plans |
| `.specify/templates/tasks-template.md` | Template for task breakdowns |
| `.github/copilot-instructions.md` | Global AI instructions (auto-loaded every chat) |
| `.editorconfig` | Code formatting standards |
| `.vscode/settings.json` | VS Code and Copilot configuration |
| `AGENTS.md` | Generic agent instructions |

### Pattern-Specific Instructions (Always Installed)

These load automatically when you edit matching file types:

| File | Loads When Editing |
|------|-------------------|
| `dotnet-api.instructions.md` | Any `.cs` file, `Program.cs`, controllers |
| `angular.instructions.md` | Any `.ts`, `.html`, `.scss` file |
| `react.instructions.md` | Any `.tsx`, `.jsx` file |
| `entity-framework.instructions.md` | DbContext, Repository, Migration files |
| `azure-entra-id.instructions.md` | Auth, Identity, Token files |
| `oauth2-swagger-scalar.instructions.md` | Scalar, OpenApi, Swagger files |
| `postgres.instructions.md` | Database-related files |
| `sqlserver.instructions.md` | Database-related files |
| `xunit-testing.instructions.md` | Test files (`.cs` in test projects) |
| `jest-vitest-testing.instructions.md` | Test files (`.test.ts`, `.spec.tsx`) |
| `azure-devops-pipelines.instructions.md` | Pipeline YAML files |
| `azure-aks.instructions.md` | Dockerfile, Kubernetes YAML files |
| `git-commit.instructions.md` | Commit message generation |

### Agent-Specific Files (Based on --agent parameter)

| File | AI Agent | Installed When |
|------|----------|---------------|
| `.cursorrules` | Cursor | `--agent cursor` or `--agent all` |
| `CLAUDE.md` | Claude Code | `--agent claude` or `--agent all` |
| `.windsurfrules` | Windsurf | `--agent windsurf` or `--agent all` |

---

## 🎯 Available Prompts (Phase 2)

These will be available via `/` in Copilot Chat after Phase 2 rollout:

| Prompt | Description |
|--------|-------------|
| `/create-api-endpoint` | Scaffold a complete API endpoint with auth and tests |
| `/create-unit-tests` | Generate xUnit tests for a class |
| `/create-angular-component` | Scaffold an Angular standalone component |
| `/create-react-component` | Scaffold a React functional component |
| `/add-auth-endpoint` | Add Entra ID authentication to an endpoint |
| `/add-swagger-scalar` | Configure Scalar with OAuth2 |
| `/create-ef-migration` | Create an EF Core migration |
| `/create-aks-deployment` | Generate Kubernetes manifests |
| `/security-review` | Run security analysis on code |
| `/performance-review` | Run performance analysis on code |

---

## 🤖 Custom Agents (Phase 2)

These specialized agents will be available after Phase 2 rollout:

| Agent | Expertise |
|-------|-----------|
| `@dotnet-architect` | API design, architecture decisions, Clean Architecture |
| `@frontend-specialist` | Angular/React components, state management, MSAL |
| `@devops-engineer` | Pipelines, AKS, Docker, KEDA, infrastructure |
| `@security-reviewer` | Auth, OWASP Top 10, vulnerability analysis |
| `@database-specialist` | EF Core, PostgreSQL, SQL Server, migrations, performance |

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|---------|
| Copilot gives generic advice, ignores project standards | Verify `.github/copilot-instructions.md` exists in your repo root |
| Instructions not loading for specific file types | Check the `applyTo` patterns in `.github/instructions/` files |
| VS Code does not show custom prompts | Update VS Code and GitHub Copilot extension to the latest version |
| Visual Studio ignores custom instructions | Enable at Tools → Options → GitHub → Copilot → Enable custom instructions |
| Cursor does not follow rules | Verify `.cursorrules` exists in your repo root |
| Claude Code does not follow rules | Verify `CLAUDE.md` exists in your repo root |
| Bootstrap script fails | Ensure PowerShell 7+ (not Windows PowerShell 5.1) or Bash 4+ |
| Git submodule not updating | Run `git submodule update --remote .ai-accelerator` |

---

## 🆘 Need Help?

- **Accelerator repo issues**: Create an issue in the accelerator repository
- **Copilot questions**: See [GitHub Copilot Docs](https://docs.github.com/copilot)
- **Constitution changes**: Submit a PR to the accelerator repo with an ADR

---

*Last updated: 2026-02-20*