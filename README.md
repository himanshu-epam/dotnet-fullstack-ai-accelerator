# 🚀 .NET Full-Stack AI Accelerator

> A shared repository enabling spec-driven, AI-powered development for all full-stack .NET applications.
> **Any team can enable AI-assisted development within minutes.**

---

## 🤔 What is this?

This repository contains **reusable AI instructions, coding standards, project templates, and automation scripts** that any .NET full-stack application team can adopt. It provides:

- 🏛️ **Organization Constitution** — Shared architectural principles and non-negotiable coding standards
- 🤖 **AI Agent Instructions** — Pre-configured instructions for GitHub Copilot, Cursor, Claude Code, Windsurf, and more
- 📝 **Reusable Prompts** — One-click prompts for common tasks (create API, add auth, write tests, deploy to AKS)
- 📐 **Spec-Driven Development** — Templates for the specify → plan → tasks → implement workflow
- ⚡ **Bootstrap Scripts** — Get AI-enabled in under 5 minutes for any existing or new application

---

## 🛠️ Supported Tech Stack

| Layer | Technology |
|-------|-----------|
| **Backend** | ASP.NET Core 8/9+, C# 12+, Entity Framework Core |
| **Frontend** | Angular 18+ **or** React 18+ (both are first-class citizens) |
| **Database** | PostgreSQL (default), SQL Server (supported) |
| **Authentication** | Azure Entra ID, OAuth 2.0 (Authorization Code + PKCE) |
| **API Documentation** | Scalar + OpenAPI (replacing Swagger UI) |
| **Testing** | xUnit + FluentAssertions (.NET), Jest / Vitest + Testing Library (UI) |
| **CI/CD** | Azure DevOps Pipelines (YAML) |
| **Deployment** | Docker → Azure Kubernetes Service (AKS) with KEDA scaling |
| **AI Agents** | GitHub Copilot, Cursor, Claude Code, Windsurf, OpenAI Codex CLI |

---

## 🏃 Quick Start (5 Minutes)

### Option A: PowerShell (Windows / Azure DevOps)

Clone the accelerator into your project, then run the bootstrap:

    cd your-project
    git clone <this-repo-url> .ai-accelerator

    .\.ai-accelerator\scaffold\init.ps1 `
      -TargetPath . `
      -Frontend angular `
      -Database postgres `
      -Agent all

### Option B: Bash (Linux / macOS)

Clone the accelerator into your project, then run the bootstrap:

    cd your-project
    git clone <this-repo-url> .ai-accelerator

    ./.ai-accelerator/scaffold/init.sh \
      --target . \
      --frontend angular \
      --database postgres \
      --agent all

### Option C: Git Submodule (Recommended — tracks updates automatically)

Add as a submodule so your project always gets the latest accelerator updates:

    cd your-project
    git submodule add <this-repo-url> .ai-accelerator

    ./.ai-accelerator/scaffold/init.sh --target . --frontend react --database postgres --agent all

---

## 📂 What Gets Installed in Your Project

After running the bootstrap, your project will have these files:

    your-app/
    ├── .github/
    │   ├── copilot-instructions.md         ← Global AI context (auto-loaded by Copilot)
    │   ├── instructions/                    ← 12+ pattern-specific instruction files
    │   │   ├── dotnet-api.instructions.md
    │   │   ├── angular.instructions.md
    │   │   ├── react.instructions.md
    │   │   ├── entity-framework.instructions.md
    │   │   ├── azure-entra-id.instructions.md
    │   │   ├── oauth2-swagger-scalar.instructions.md
    │   │   ├── postgres.instructions.md
    │   │   ├── sqlserver.instructions.md
    │   │   ├── xunit-testing.instructions.md
    │   │   ├── jest-vitest-testing.instructions.md
    │   │   ├── azure-devops-pipelines.instructions.md
    │   │   ├── azure-aks.instructions.md
    │   │   └── git-commit.instructions.md
    │   ├── prompts/                         ← Reusable prompts (Phase 2)
    │   └── agents/                          ← Custom AI agents (Phase 2)
    ├── .specify/
    │   ├── memory/
    │   │   └── constitution.md              ← Organization standards and principles
    │   └── templates/                       ← Spec / Plan / Tasks templates
    ├── .cursorrules                         ← Cursor AI rules (if selected)
    ├── CLAUDE.md                            ← Claude Code rules (if selected)
    ├── .windsurfrules                       ← Windsurf rules (if selected)
    ├── AGENTS.md                            ← Generic agent rules
    ├── .editorconfig                        ← Code formatting standards
    └── .vscode/settings.json                ← VS Code + Copilot configuration


---

## 🔄 How It Works

### AI Instructions Load Automatically

| File | When It Loads | AI Agent |
|------|--------------|----------|
| `.github/copilot-instructions.md` | Every Copilot Chat interaction | GitHub Copilot |
| `.github/instructions/*.instructions.md` | When editing matching file patterns | GitHub Copilot |
| `.cursorrules` | Every Cursor interaction | Cursor |
| `CLAUDE.md` | Every Claude Code interaction | Claude Code |
| `.windsurfrules` | Every Windsurf interaction | Windsurf |
| `AGENTS.md` | Every Codex CLI interaction | OpenAI Codex |
| `.specify/memory/constitution.md` | Referenced by all agents and Spec Kit | All agents |

### Spec-Driven Development Workflow

    Step 1:  /specify  →  Define WHAT you want to build (features, user stories)
    Step 2:  /plan     →  Create a technical implementation plan
    Step 3:  /tasks    →  Break down into actionable, parallelizable tasks
    Step 4:  implement →  Execute tasks with AI assistance

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Onboarding Guide](./ONBOARDING.md) | Step-by-step: enable AI in 5 minutes |
| [Constitution](./.specify/memory/constitution.md) | Organization-wide standards and principles |
| [Coding Standards](./docs/coding-standards/) | Detailed coding guidelines by technology |
| [Architecture Decision Records](./docs/architecture-decision-records/) | ADRs for key decisions |
| [How-To Guides](./docs/how-to/) | Step-by-step guides for common scenarios |

---

## 🤝 Contributing

All teams are encouraged to contribute improvements:

1. **New or improved instructions** — Better patterns for existing technologies
2. **New reusable prompts** — Common tasks your team automates
3. **Bug fixes** — Corrections to templates or scripts
4. **New how-to guides** — Document solutions to common problems

### How to Contribute

1. Create a feature branch: `feat/add-xyz-instructions`
2. Make your changes
3. Submit a PR with at least 1 reviewer
4. Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`

---

## 📊 Compatibility Matrix

| Feature | GitHub Copilot | Cursor | Claude Code | Windsurf | Codex CLI |
|---------|:-:|:-:|:-:|:-:|:-:|
| copilot-instructions.md | ✅ | ✅ | — | — | — |
| .instructions.md files | ✅ | ✅ | — | — | — |
| .prompt.md files | ✅ | ✅ | — | — | — |
| .agent.md files | ✅ | — | — | — | — |
| .cursorrules | — | ✅ | — | — | — |
| CLAUDE.md | — | — | ✅ | — | — |
| .windsurfrules | — | — | — | ✅ | — |
| AGENTS.md | — | — | — | — | ✅ |
| .specify/ (Spec Kit) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Constitution | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 📜 License

Internal use only — ©️ EPAM.