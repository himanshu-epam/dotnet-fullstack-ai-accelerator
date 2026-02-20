#!/usr/bin/env bash
#
# .NET Full-Stack AI Accelerator — Bootstrap Script
#
# Usage:
#   ./init.sh --target /path/to/project --frontend angular --database postgres --agent all
#
# Parameters:
#   --target     Path to the target application repository (required)
#   --frontend   Frontend framework: angular or react (default: angular)
#   --database   Database: postgres or sqlserver (default: postgres)
#   --agent      AI agent: copilot, cursor, claude, windsurf, all (default: all)
#

set -euo pipefail

# ─── Colors ───

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# ─── Parse Arguments ───

TARGET_PATH=""
FRONTEND="angular"
DATABASE="postgres"
AGENT="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET_PATH="$2"
            shift 2
            ;;
        --frontend)
            FRONTEND="$2"
            shift 2
            ;;
        --database)
            DATABASE="$2"
            shift 2
            ;;
        --agent)
            AGENT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./init.sh --target /path/to/project [--frontend angular|react] [--database postgres|sqlserver] [--agent copilot|cursor|claude|windsurf|all]"
            echo ""
            echo "Parameters:"
            echo "  --target     Path to the target application repository (required)"
            echo "  --frontend   Frontend framework: angular or react (default: angular)"
            echo "  --database   Database: postgres or sqlserver (default: postgres)"
            echo "  --agent      AI agent: copilot, cursor, claude, windsurf, all (default: all)"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Run ./init.sh --help for usage information."
            exit 1
            ;;
    esac
done

# ─── Validate Arguments ───

if [[ -z "$TARGET_PATH" ]]; then
    echo -e "${RED}❌ --target is required${NC}"
    echo "Usage: ./init.sh --target /path/to/project --frontend angular --database postgres --agent all"
    exit 1
fi

if [[ ! -d "$TARGET_PATH" ]]; then
    echo -e "${RED}❌ Target path does not exist: $TARGET_PATH${NC}"
    exit 1
fi

if [[ "$FRONTEND" != "angular" && "$FRONTEND" != "react" ]]; then
    echo -e "${RED}❌ Invalid frontend: $FRONTEND (must be 'angular' or 'react')${NC}"
    exit 1
fi

if [[ "$DATABASE" != "postgres" && "$DATABASE" != "sqlserver" ]]; then
    echo -e "${RED}❌ Invalid database: $DATABASE (must be 'postgres' or 'sqlserver')${NC}"
    exit 1
fi

if [[ "$AGENT" != "copilot" && "$AGENT" != "cursor" && "$AGENT" != "claude" && "$AGENT" != "windsurf" && "$AGENT" != "all" ]]; then
    echo -e "${RED}❌ Invalid agent: $AGENT (must be 'copilot', 'cursor', 'claude', 'windsurf', or 'all')${NC}"
    exit 1
fi

# ─── Resolve Paths ───

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCELERATOR_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"

# Verify accelerator structure
if [[ ! -d "$ACCELERATOR_ROOT/.specify" ]]; then
    echo -e "${RED}❌ Cannot find accelerator structure. Run this script from the scaffold/ directory.${NC}"
    exit 1
fi

# ─── Banner ───

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🚀 .NET Full-Stack AI Accelerator               ║${NC}"
echo -e "${CYAN}║  Bootstrapping AI-enabled development...          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Target:     ${WHITE}$TARGET_PATH${NC}"
echo -e "  Frontend:   ${WHITE}$FRONTEND${NC}"
echo -e "  Database:   ${WHITE}$DATABASE${NC}"
echo -e "  AI Agent:   ${WHITE}$AGENT${NC}"
echo ""

# ─── Helper Functions ───

FILES_INSTALLED=0

copy_safe() {
    local source="$1"
    local destination="$2"

    if [[ ! -e "$source" ]]; then
        echo -e "    ${YELLOW}⚠️  Source not found, skipping: $source${NC}"
        return 1
    fi

    local dest_dir
    dest_dir="$(dirname "$destination")"
    mkdir -p "$dest_dir"

    cp -f "$source" "$destination"
    FILES_INSTALLED=$((FILES_INSTALLED + 1))
    return 0
}

copy_safe_dir() {
    local source="$1"
    local destination="$2"

    if [[ ! -d "$source" ]]; then
        echo -e "    ${YELLOW}⚠️  Source directory not found, skipping: $source${NC}"
        return 1
    fi

    mkdir -p "$destination"
    cp -rf "$source/"* "$destination/" 2>/dev/null || true
    return 0
}

TOTAL_STEPS=8
CURRENT_STEP=0

# ─── Step 1: Spec-Driven Development ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}📋 [$CURRENT_STEP/$TOTAL_STEPS] Installing Spec-Driven Development templates...${NC}"

mkdir -p "$TARGET_PATH/.specify/memory"
mkdir -p "$TARGET_PATH/.specify/templates"

# Constitution
if copy_safe \
    "$ACCELERATOR_ROOT/.specify/memory/constitution.md" \
    "$TARGET_PATH/.specify/memory/constitution.md"; then
    echo -e "    ${GREEN}✅ Constitution installed${NC}"
fi

# Spec templates
TEMPLATE_COUNT=0
for template in spec-template.md plan-template.md tasks-template.md; do
    if copy_safe \
        "$ACCELERATOR_ROOT/.specify/templates/$template" \
        "$TARGET_PATH/.specify/templates/$template"; then
        TEMPLATE_COUNT=$((TEMPLATE_COUNT + 1))
    fi
done
echo -e "    ${GREEN}✅ Spec/Plan/Tasks templates installed ($TEMPLATE_COUNT files)${NC}"

# ─── Step 2: Global Copilot Instructions ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}🤖 [$CURRENT_STEP/$TOTAL_STEPS] Installing GitHub Copilot global instructions...${NC}"

mkdir -p "$TARGET_PATH/.github"

if copy_safe \
    "$ACCELERATOR_ROOT/.github/copilot-instructions.md" \
    "$TARGET_PATH/.github/copilot-instructions.md"; then
    echo -e "    ${GREEN}✅ Global copilot-instructions.md installed${NC}"
fi

# ─── Step 3: Pattern-Specific Instructions ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}📐 [$CURRENT_STEP/$TOTAL_STEPS] Installing pattern-specific instruction files...${NC}"

mkdir -p "$TARGET_PATH/.github/instructions"

INSTRUCTIONS_SOURCE="$ACCELERATOR_ROOT/.github/instructions"
INSTRUCTIONS_TARGET="$TARGET_PATH/.github/instructions"

# Always install these
ALWAYS_INSTALL=(
    "dotnet-api.instructions.md"
    "entity-framework.instructions.md"
    "azure-entra-id.instructions.md"
    "oauth2-swagger-scalar.instructions.md"
    "xunit-testing.instructions.md"
    "jest-vitest-testing.instructions.md"
    "azure-devops-pipelines.instructions.md"
    "azure-aks.instructions.md"
    "git-commit.instructions.md"
)

for file in "${ALWAYS_INSTALL[@]}"; do
    copy_safe "$INSTRUCTIONS_SOURCE/$file" "$INSTRUCTIONS_TARGET/$file"
done

# Frontend-specific
if [[ "$FRONTEND" == "angular" ]]; then
    if copy_safe "$INSTRUCTIONS_SOURCE/angular.instructions.md" "$INSTRUCTIONS_TARGET/angular.instructions.md"; then
        echo -e "    ${GREEN}✅ Angular instructions installed${NC}"
    fi
elif [[ "$FRONTEND" == "react" ]]; then
    if copy_safe "$INSTRUCTIONS_SOURCE/react.instructions.md" "$INSTRUCTIONS_TARGET/react.instructions.md"; then
        echo -e "    ${GREEN}✅ React instructions installed${NC}"
    fi
fi

# Database-specific
if [[ "$DATABASE" == "postgres" ]]; then
    if copy_safe "$INSTRUCTIONS_SOURCE/postgres.instructions.md" "$INSTRUCTIONS_TARGET/postgres.instructions.md"; then
        echo -e "    ${GREEN}✅ PostgreSQL instructions installed${NC}"
    fi
elif [[ "$DATABASE" == "sqlserver" ]]; then
    if copy_safe "$INSTRUCTIONS_SOURCE/sqlserver.instructions.md" "$INSTRUCTIONS_TARGET/sqlserver.instructions.md"; then
        echo -e "    ${GREEN}✅ SQL Server instructions installed${NC}"
    fi
fi

INSTRUCTION_COUNT=$(find "$INSTRUCTIONS_TARGET" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
echo -e "    ${GREEN}✅ $INSTRUCTION_COUNT instruction files installed${NC}"

# ─── Step 4: Prompts and Agents ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}🎯 [$CURRENT_STEP/$TOTAL_STEPS] Installing prompts and agents...${NC}"

PROMPTS_SOURCE="$ACCELERATOR_ROOT/.github/prompts"
if [[ -d "$PROMPTS_SOURCE" ]] && [[ -n "$(ls -A "$PROMPTS_SOURCE" 2>/dev/null)" ]]; then
    mkdir -p "$TARGET_PATH/.github/prompts"
    copy_safe_dir "$PROMPTS_SOURCE" "$TARGET_PATH/.github/prompts"
    PROMPT_COUNT=$(find "$PROMPTS_SOURCE" -type f 2>/dev/null | wc -l | tr -d ' ')
    FILES_INSTALLED=$((FILES_INSTALLED + PROMPT_COUNT))
    echo -e "    ${GREEN}✅ $PROMPT_COUNT prompt files installed${NC}"
else
    echo -e "    ${YELLOW}⏭️  No prompts yet (will be added in Phase 2)${NC}"
fi

AGENTS_SOURCE="$ACCELERATOR_ROOT/.github/agents"
if [[ -d "$AGENTS_SOURCE" ]] && [[ -n "$(ls -A "$AGENTS_SOURCE" 2>/dev/null)" ]]; then
    mkdir -p "$TARGET_PATH/.github/agents"
    copy_safe_dir "$AGENTS_SOURCE" "$TARGET_PATH/.github/agents"
    AGENT_COUNT=$(find "$AGENTS_SOURCE" -type f 2>/dev/null | wc -l | tr -d ' ')
    FILES_INSTALLED=$((FILES_INSTALLED + AGENT_COUNT))
    echo -e "    ${GREEN}✅ $AGENT_COUNT agent files installed${NC}"
else
    echo -e "    ${YELLOW}⏭️  No agents yet (will be added in Phase 2)${NC}"
fi

# ─── Step 5: AI Agent-Specific Rules ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}🔧 [$CURRENT_STEP/$TOTAL_STEPS] Installing AI agent rules...${NC}"

# AGENTS.md always installed (generic fallback)
if copy_safe "$ACCELERATOR_ROOT/ai-rules/AGENTS.md" "$TARGET_PATH/AGENTS.md"; then
    echo -e "    ${GREEN}✅ AGENTS.md (generic agent rules)${NC}"
fi

# Copilot already installed via copilot-instructions.md
if [[ "$AGENT" == "copilot" || "$AGENT" == "all" ]]; then
    echo -e "    ${GREEN}✅ GitHub Copilot (via copilot-instructions.md)${NC}"
fi

# Cursor
if [[ "$AGENT" == "cursor" || "$AGENT" == "all" ]]; then
    if copy_safe "$ACCELERATOR_ROOT/ai-rules/.cursorrules" "$TARGET_PATH/.cursorrules"; then
        echo -e "    ${GREEN}✅ .cursorrules (Cursor AI)${NC}"
    fi
fi

# Claude Code
if [[ "$AGENT" == "claude" || "$AGENT" == "all" ]]; then
    if copy_safe "$ACCELERATOR_ROOT/ai-rules/CLAUDE.md" "$TARGET_PATH/CLAUDE.md"; then
        echo -e "    ${GREEN}✅ CLAUDE.md (Claude Code)${NC}"
    fi
fi

# Windsurf
if [[ "$AGENT" == "windsurf" || "$AGENT" == "all" ]]; then
    if copy_safe "$ACCELERATOR_ROOT/ai-rules/.windsurfrules" "$TARGET_PATH/.windsurfrules"; then
        echo -e "    ${GREEN}✅ .windsurfrules (Windsurf)${NC}"
    fi
fi

# ─── Step 6: EditorConfig ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}📐 [$CURRENT_STEP/$TOTAL_STEPS] Installing code formatting standards...${NC}"

if copy_safe "$ACCELERATOR_ROOT/.editorconfig" "$TARGET_PATH/.editorconfig"; then
    echo -e "    ${GREEN}✅ .editorconfig installed${NC}"
fi

# ─── Step 7: VS Code Settings ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}⚙️  [$CURRENT_STEP/$TOTAL_STEPS] Installing VS Code settings...${NC}"

mkdir -p "$TARGET_PATH/.vscode"

VSCODE_SOURCE="$ACCELERATOR_ROOT/.vscode/settings.json"
VSCODE_DEST="$TARGET_PATH/.vscode/settings.json"

if [[ -f "$VSCODE_DEST" ]]; then
    echo -e "    ${YELLOW}⚠️  .vscode/settings.json already exists${NC}"
    read -rp "    Overwrite? (y/N): " OVERWRITE
    if [[ "$OVERWRITE" == "y" || "$OVERWRITE" == "Y" ]]; then
        if copy_safe "$VSCODE_SOURCE" "$VSCODE_DEST"; then
            echo -e "    ${GREEN}✅ .vscode/settings.json overwritten${NC}"
        fi
    else
        echo -e "    ${YELLOW}⏭️  Skipped .vscode/settings.json${NC}"
    fi
else
    if copy_safe "$VSCODE_SOURCE" "$VSCODE_DEST"; then
        echo -e "    ${GREEN}✅ .vscode/settings.json installed${NC}"
    fi
fi

# ─── Step 8: Verify Installation ───

CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${YELLOW}🔍 [$CURRENT_STEP/$TOTAL_STEPS] Verifying installation...${NC}"

VERIFICATION_ERRORS=0

# Check critical files
declare -A CRITICAL_FILES
CRITICAL_FILES=(
    ["Constitution"]="$TARGET_PATH/.specify/memory/constitution.md"
    ["Copilot Instructions"]="$TARGET_PATH/.github/copilot-instructions.md"
    ["EditorConfig"]="$TARGET_PATH/.editorconfig"
)

for name in "${!CRITICAL_FILES[@]}"; do
    path="${CRITICAL_FILES[$name]}"
    if [[ -f "$path" ]]; then
        echo -e "    ${GREEN}✅ $name verified${NC}"
    else
        echo -e "    ${RED}❌ $name MISSING${NC}"
        VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
    fi
done

# Check instruction file count
INSTALLED_INSTRUCTIONS=$(find "$TARGET_PATH/.github/instructions" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$INSTALLED_INSTRUCTIONS" -ge 10 ]]; then
    echo -e "    ${GREEN}✅ $INSTALLED_INSTRUCTIONS instruction files verified${NC}"
else
    echo -e "    ${YELLOW}⚠️  Only $INSTALLED_INSTRUCTIONS instruction files found (expected 10+)${NC}"
    VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
fi

# ─── Summary ───

echo ""
if [[ "$VERIFICATION_ERRORS" -eq 0 ]]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ AI-enabled development bootstrapped!          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  Bootstrap completed with warnings            ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "  ${WHITE}📊 Summary:${NC}"
echo -e "     Files installed:  ${WHITE}$FILES_INSTALLED${NC}"
echo -e "     Frontend:         ${WHITE}$FRONTEND${NC}"
echo -e "     Database:         ${WHITE}$DATABASE${NC}"
echo -e "     AI Agent(s):      ${WHITE}$AGENT${NC}"
echo ""
echo -e "  ${WHITE}📂 Installed:${NC}"
echo -e "     ${GRAY}.specify/memory/constitution.md       → Org standards${NC}"
echo -e "     ${GRAY}.specify/templates/ (3 files)         → Spec/Plan/Tasks templates${NC}"
echo -e "     ${GRAY}.github/copilot-instructions.md       → Global AI context${NC}"
echo -e "     ${GRAY}.github/instructions/ ($INSTALLED_INSTRUCTIONS files)     → Pattern-specific rules${NC}"
echo -e "     ${GRAY}.editorconfig                         → Code formatting${NC}"

if [[ "$AGENT" == "cursor" || "$AGENT" == "all" ]]; then
    echo -e "     ${GRAY}.cursorrules                          → Cursor AI rules${NC}"
fi
if [[ "$AGENT" == "claude" || "$AGENT" == "all" ]]; then
    echo -e "     ${GRAY}CLAUDE.md                             → Claude Code rules${NC}"
fi
if [[ "$AGENT" == "windsurf" || "$AGENT" == "all" ]]; then
    echo -e "     ${GRAY}.windsurfrules                        → Windsurf rules${NC}"
fi
echo -e "     ${GRAY}AGENTS.md                             → Generic agent rules${NC}"

echo ""
echo -e "  ${CYAN}🚀 Next Steps:${NC}"
echo -e "     ${WHITE}1. Open your project in VS Code / Visual Studio / Cursor${NC}"
echo -e "     ${WHITE}2. GitHub Copilot will automatically load all instructions${NC}"
echo -e "     ${WHITE}3. Open Copilot Chat and ask:${NC}"
echo -e "        ${GRAY}@workspace What coding standards does this project follow?${NC}"
echo -e "     ${WHITE}4. Start building with spec-driven development:${NC}"
echo -e "        ${GRAY}Create a spec for: <your feature description>${NC}"
echo ""
echo -e "  ${WHITE}📖 Full guide: See ONBOARDING.md in the accelerator repo${NC}"
echo ""
