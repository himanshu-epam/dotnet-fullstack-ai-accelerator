#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Bootstrap AI-enabled development for any .NET full-stack application.

.DESCRIPTION
    Copies AI instructions, templates, prompts, and configurations from the
    shared accelerator repository into the target application repository.
    After running this script, AI agents (Copilot, Cursor, Claude, Windsurf)
    will automatically understand your tech stack and coding standards.

.PARAMETER TargetPath
    Path to the target application repository. Required.

.PARAMETER Frontend
    Frontend framework: 'angular' or 'react'. Default: 'angular'.

.PARAMETER Database
    Database: 'postgres' or 'sqlserver'. Default: 'postgres'.

.PARAMETER Agent
    AI agent to configure: 'copilot', 'cursor', 'claude', 'windsurf', 'all'.
    Default: 'all'.

.EXAMPLE
    .\init.ps1 -TargetPath . -Frontend angular -Database postgres -Agent all

.EXAMPLE
    .\init.ps1 -TargetPath C:\Projects\MyApp -Frontend react -Database sqlserver -Agent copilot
#>
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the target application repository")]
    [string]$TargetPath,

    [Parameter(HelpMessage = "Frontend framework: angular or react")]
    [ValidateSet('angular', 'react')]
    [string]$Frontend = 'angular',

    [Parameter(HelpMessage = "Database: postgres or sqlserver")]
    [ValidateSet('postgres', 'sqlserver')]
    [string]$Database = 'postgres',

    [Parameter(HelpMessage = "AI agent: copilot, cursor, claude, windsurf, all")]
    [ValidateSet('copilot', 'cursor', 'claude', 'windsurf', 'all')]
    [string]$Agent = 'all'
)

$ErrorActionPreference = 'Stop'

# ─── Resolve Paths ───

$AcceleratorRoot = Split-Path -Parent $PSScriptRoot

# Resolve target path
if (-not (Test-Path $TargetPath)) {
    Write-Error "Target path does not exist: $TargetPath"
    exit 1
}
$TargetPath = (Resolve-Path $TargetPath).Path

# Verify accelerator structure
if (-not (Test-Path (Join-Path $AcceleratorRoot ".specify"))) {
    Write-Error "Cannot find accelerator structure. Run this script from the scaffold/ directory."
    exit 1
}

# ─── Banner ───

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🚀 .NET Full-Stack AI Accelerator               ║" -ForegroundColor Cyan
Write-Host "║  Bootstrapping AI-enabled development...          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Target:     $TargetPath" -ForegroundColor White
Write-Host "  Frontend:   $Frontend" -ForegroundColor White
Write-Host "  Database:   $Database" -ForegroundColor White
Write-Host "  AI Agent:   $Agent" -ForegroundColor White
Write-Host ""

# ─── Helper Function ───

function Copy-SafeItem {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$Recurse
    )

    if (-not (Test-Path $Source)) {
        Write-Host "    ⚠️  Source not found, skipping: $Source" -ForegroundColor DarkYellow
        return $false
    }

    $destDir = if ($Recurse) { Split-Path -Parent $Destination } else { Split-Path -Parent $Destination }
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    }

    if ($Recurse) {
        Copy-Item -Path $Source -Destination $Destination -Recurse -Force
    }
    else {
        Copy-Item -Path $Source -Destination $Destination -Force
    }

    return $true
}

$stepCount = 0
$totalSteps = 8
$filesInstalled = 0

# ─── Step 1: Spec-Driven Development ───

$stepCount++
Write-Host "📋 [$stepCount/$totalSteps] Installing Spec-Driven Development templates..." -ForegroundColor Yellow

$specifyTarget = Join-Path $TargetPath ".specify"
if (-not (Test-Path $specifyTarget)) {
    New-Item -Path $specifyTarget -ItemType Directory -Force | Out-Null
}

$memoryTarget = Join-Path $specifyTarget "memory"
if (-not (Test-Path $memoryTarget)) {
    New-Item -Path $memoryTarget -ItemType Directory -Force | Out-Null
}

$templatesTarget = Join-Path $specifyTarget "templates"
if (-not (Test-Path $templatesTarget)) {
    New-Item -Path $templatesTarget -ItemType Directory -Force | Out-Null
}

# Copy constitution
if (Copy-SafeItem -Source (Join-Path $AcceleratorRoot ".specify" "memory" "constitution.md") -Destination (Join-Path $memoryTarget "constitution.md")) {
    $filesInstalled++
    Write-Host "    ✅ Constitution installed" -ForegroundColor Green
}

# Copy spec templates
$specTemplates = @("spec-template.md", "plan-template.md", "tasks-template.md")
foreach ($template in $specTemplates) {
    $source = Join-Path $AcceleratorRoot ".specify" "templates" $template
    $dest = Join-Path $templatesTarget $template
    if (Copy-SafeItem -Source $source -Destination $dest) {
        $filesInstalled++
    }
}
Write-Host "    ✅ Spec/Plan/Tasks templates installed ($($specTemplates.Count) files)" -ForegroundColor Green

# ─── Step 2: Global Copilot Instructions ───

$stepCount++
Write-Host "🤖 [$stepCount/$totalSteps] Installing GitHub Copilot global instructions..." -ForegroundColor Yellow

$githubTarget = Join-Path $TargetPath ".github"
if (-not (Test-Path $githubTarget)) {
    New-Item -Path $githubTarget -ItemType Directory -Force | Out-Null
}

if (Copy-SafeItem -Source (Join-Path $AcceleratorRoot ".github" "copilot-instructions.md") -Destination (Join-Path $githubTarget "copilot-instructions.md")) {
    $filesInstalled++
    Write-Host "    ✅ Global copilot-instructions.md installed" -ForegroundColor Green
}

# ─── Step 3: Pattern-Specific Instructions ───

$stepCount++
Write-Host "📐 [$stepCount/$totalSteps] Installing pattern-specific instruction files..." -ForegroundColor Yellow

$instructionsTarget = Join-Path $githubTarget "instructions"
if (-not (Test-Path $instructionsTarget)) {
    New-Item -Path $instructionsTarget -ItemType Directory -Force | Out-Null
}

$instructionsSource = Join-Path $AcceleratorRoot ".github" "instructions"

# Always install these instruction files
$alwaysInstall = @(
    "dotnet-api.instructions.md",
    "entity-framework.instructions.md",
    "azure-entra-id.instructions.md",
    "oauth2-swagger-scalar.instructions.md",
    "xunit-testing.instructions.md",
    "jest-vitest-testing.instructions.md",
    "azure-devops-pipelines.instructions.md",
    "azure-aks.instructions.md",
    "git-commit.instructions.md"
)

foreach ($file in $alwaysInstall) {
    $source = Join-Path $instructionsSource $file
    $dest = Join-Path $instructionsTarget $file
    if (Copy-SafeItem -Source $source -Destination $dest) {
        $filesInstalled++
    }
}

# Install frontend-specific instructions
if ($Frontend -eq 'angular') {
    $source = Join-Path $instructionsSource "angular.instructions.md"
    $dest = Join-Path $instructionsTarget "angular.instructions.md"
    if (Copy-SafeItem -Source $source -Destination $dest) {
        $filesInstalled++
        Write-Host "    ✅ Angular instructions installed" -ForegroundColor Green
    }
}
elseif ($Frontend -eq 'react') {
    $source = Join-Path $instructionsSource "react.instructions.md"
    $dest = Join-Path $instructionsTarget "react.instructions.md"
    if (Copy-SafeItem -Source $source -Destination $dest) {
        $filesInstalled++
        Write-Host "    ✅ React instructions installed" -ForegroundColor Green
    }
}

# Install database-specific instructions
if ($Database -eq 'postgres') {
    $source = Join-Path $instructionsSource "postgres.instructions.md"
    $dest = Join-Path $instructionsTarget "postgres.instructions.md"
    if (Copy-SafeItem -Source $source -Destination $dest) {
        $filesInstalled++
        Write-Host "    ✅ PostgreSQL instructions installed" -ForegroundColor Green
    }
}
elseif ($Database -eq 'sqlserver') {
    $source = Join-Path $instructionsSource "sqlserver.instructions.md"
    $dest = Join-Path $instructionsTarget "sqlserver.instructions.md"
    if (Copy-SafeItem -Source $source -Destination $dest) {
        $filesInstalled++
        Write-Host "    ✅ SQL Server instructions installed" -ForegroundColor Green
    }
}

$totalInstructions = $alwaysInstall.Count + 2  # +1 frontend +1 database
Write-Host "    ✅ $totalInstructions instruction files installed" -ForegroundColor Green

# ─── Step 4: Prompts and Agents ───

$stepCount++
Write-Host "🎯 [$stepCount/$totalSteps] Installing prompts and agents..." -ForegroundColor Yellow

$promptsSource = Join-Path $AcceleratorRoot ".github" "prompts"
if (Test-Path $promptsSource) {
    $promptsTarget = Join-Path $githubTarget "prompts"
    Copy-SafeItem -Source $promptsSource -Destination $promptsTarget -Recurse | Out-Null
    $promptCount = (Get-ChildItem -Path $promptsSource -File -Recurse).Count
    $filesInstalled += $promptCount
    Write-Host "    ✅ $promptCount prompt files installed" -ForegroundColor Green
}
else {
    Write-Host "    ⏭️  No prompts yet (will be added in Phase 2)" -ForegroundColor DarkYellow
}

$agentsSource = Join-Path $AcceleratorRoot ".github" "agents"
if (Test-Path $agentsSource) {
    $agentsTarget = Join-Path $githubTarget "agents"
    Copy-SafeItem -Source $agentsSource -Destination $agentsTarget -Recurse | Out-Null
    $agentCount = (Get-ChildItem -Path $agentsSource -File -Recurse).Count
    $filesInstalled += $agentCount
    Write-Host "    ✅ $agentCount agent files installed" -ForegroundColor Green
}
else {
    Write-Host "    ⏭️  No agents yet (will be added in Phase 2)" -ForegroundColor DarkYellow
}

# ─── Step 5: AI Agent-Specific Rules ───

$stepCount++
Write-Host "🔧 [$stepCount/$totalSteps] Installing AI agent rules..." -ForegroundColor Yellow

# AGENTS.md is always installed (generic fallback)
$agentsMdSource = Join-Path $AcceleratorRoot "ai-rules" "AGENTS.md"
if (Copy-SafeItem -Source $agentsMdSource -Destination (Join-Path $TargetPath "AGENTS.md")) {
    $filesInstalled++
    Write-Host "    ✅ AGENTS.md (generic agent rules)" -ForegroundColor Green
}

# Copilot rules are already installed via copilot-instructions.md (Step 2)
if ($Agent -eq 'copilot' -or $Agent -eq 'all') {
    Write-Host "    ✅ GitHub Copilot (via copilot-instructions.md)" -ForegroundColor Green
}

# Cursor
if ($Agent -eq 'cursor' -or $Agent -eq 'all') {
    $source = Join-Path $AcceleratorRoot "ai-rules" ".cursorrules"
    if (Copy-SafeItem -Source $source -Destination (Join-Path $TargetPath ".cursorrules")) {
        $filesInstalled++
        Write-Host "    ✅ .cursorrules (Cursor AI)" -ForegroundColor Green
    }
}

# Claude Code
if ($Agent -eq 'claude' -or $Agent -eq 'all') {
    $source = Join-Path $AcceleratorRoot "ai-rules" "CLAUDE.md"
    if (Copy-SafeItem -Source $source -Destination (Join-Path $TargetPath "CLAUDE.md")) {
        $filesInstalled++
        Write-Host "    ✅ CLAUDE.md (Claude Code)" -ForegroundColor Green
    }
}

# Windsurf
if ($Agent -eq 'windsurf' -or $Agent -eq 'all') {
    $source = Join-Path $AcceleratorRoot "ai-rules" ".windsurfrules"
    if (Copy-SafeItem -Source $source -Destination (Join-Path $TargetPath ".windsurfrules")) {
        $filesInstalled++
        Write-Host "    ✅ .windsurfrules (Windsurf)" -ForegroundColor Green
    }
}

# ─── Step 6: EditorConfig ───

$stepCount++
Write-Host "📐 [$stepCount/$totalSteps] Installing code formatting standards..." -ForegroundColor Yellow

$editorConfigSource = Join-Path $AcceleratorRoot ".editorconfig"
if (Copy-SafeItem -Source $editorConfigSource -Destination (Join-Path $TargetPath ".editorconfig")) {
    $filesInstalled++
    Write-Host "    ✅ .editorconfig installed" -ForegroundColor Green
}

# ─── Step 7: VS Code Settings ───

$stepCount++
Write-Host "⚙️  [$stepCount/$totalSteps] Installing VS Code settings..." -ForegroundColor Yellow

$vscodeTarget = Join-Path $TargetPath ".vscode"
if (-not (Test-Path $vscodeTarget)) {
    New-Item -Path $vscodeTarget -ItemType Directory -Force | Out-Null
}

$vscodeSource = Join-Path $AcceleratorRoot ".vscode" "settings.json"
$vscodeDestination = Join-Path $vscodeTarget "settings.json"

if (Test-Path $vscodeDestination) {
    Write-Host "    ⚠️  .vscode/settings.json already exists" -ForegroundColor DarkYellow
    $overwrite = Read-Host "    Overwrite? (y/N)"
    if ($overwrite -eq 'y' -or $overwrite -eq 'Y') {
        if (Copy-SafeItem -Source $vscodeSource -Destination $vscodeDestination) {
            $filesInstalled++
            Write-Host "    ✅ .vscode/settings.json overwritten" -ForegroundColor Green
        }
    }
    else {
        Write-Host "    ⏭️  Skipped .vscode/settings.json" -ForegroundColor DarkYellow
    }
}
else {
    if (Copy-SafeItem -Source $vscodeSource -Destination $vscodeDestination) {
        $filesInstalled++
        Write-Host "    ✅ .vscode/settings.json installed" -ForegroundColor Green
    }
}

# ─── Step 8: Verify Installation ───

$stepCount++
Write-Host "🔍 [$stepCount/$totalSteps] Verifying installation..." -ForegroundColor Yellow

$verificationErrors = @()

# Check critical files
$criticalFiles = @(
    @{ Path = (Join-Path $TargetPath ".specify" "memory" "constitution.md"); Name = "Constitution" },
    @{ Path = (Join-Path $TargetPath ".github" "copilot-instructions.md"); Name = "Copilot Instructions" },
    @{ Path = (Join-Path $TargetPath ".editorconfig"); Name = "EditorConfig" }
)

foreach ($file in $criticalFiles) {
    if (Test-Path $file.Path) {
        Write-Host "    ✅ $($file.Name) verified" -ForegroundColor Green
    }
    else {
        $verificationErrors += $file.Name
        Write-Host "    ❌ $($file.Name) MISSING" -ForegroundColor Red
    }
}

# Check instruction files count
$installedInstructions = Get-ChildItem -Path (Join-Path $TargetPath ".github" "instructions") -Filter "*.md" -File -ErrorAction SilentlyContinue
$instructionCount = if ($installedInstructions) { $installedInstructions.Count } else { 0 }

if ($instructionCount -ge 10) {
    Write-Host "    ✅ $instructionCount instruction files verified" -ForegroundColor Green
}
else {
    $verificationErrors += "Instruction files (expected 10+, found $instructionCount)"
    Write-Host "    ⚠️  Only $instructionCount instruction files found (expected 10+)" -ForegroundColor DarkYellow
}

# ─── Summary ───

Write-Host ""
if ($verificationErrors.Count -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✅ AI-enabled development bootstrapped!          ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
}
else {
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  ⚠️  Bootstrap completed with warnings            ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Issues found:" -ForegroundColor Yellow
    foreach ($err in $verificationErrors) {
        Write-Host "    - $err" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  📊 Summary:" -ForegroundColor White
Write-Host "     Files installed:  $filesInstalled" -ForegroundColor White
Write-Host "     Frontend:         $Frontend" -ForegroundColor White
Write-Host "     Database:         $Database" -ForegroundColor White
Write-Host "     AI Agent(s):      $Agent" -ForegroundColor White
Write-Host ""
Write-Host "  📂 Installed:" -ForegroundColor White
Write-Host "     .specify/memory/constitution.md       → Org standards" -ForegroundColor Gray
Write-Host "     .specify/templates/ (3 files)         → Spec/Plan/Tasks templates" -ForegroundColor Gray
Write-Host "     .github/copilot-instructions.md       → Global AI context" -ForegroundColor Gray
Write-Host "     .github/instructions/ ($instructionCount files)     → Pattern-specific rules" -ForegroundColor Gray
Write-Host "     .editorconfig                         → Code formatting" -ForegroundColor Gray

if ($Agent -eq 'cursor' -or $Agent -eq 'all') {
    Write-Host "     .cursorrules                          → Cursor AI rules" -ForegroundColor Gray
}
if ($Agent -eq 'claude' -or $Agent -eq 'all') {
    Write-Host "     CLAUDE.md                             → Claude Code rules" -ForegroundColor Gray
}
if ($Agent -eq 'windsurf' -or $Agent -eq 'all') {
    Write-Host "     .windsurfrules                        → Windsurf rules" -ForegroundColor Gray
}
Write-Host "     AGENTS.md                             → Generic agent rules" -ForegroundColor Gray

Write-Host ""
Write-Host "  🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "     1. Open your project in VS Code / Visual Studio / Cursor" -ForegroundColor White
Write-Host "     2. GitHub Copilot will automatically load all instructions" -ForegroundColor White
Write-Host "     3. Open Copilot Chat and ask:" -ForegroundColor White
Write-Host "        @workspace What coding standards does this project follow?" -ForegroundColor Gray
Write-Host "     4. Start building with spec-driven development:" -ForegroundColor White
Write-Host "        Create a spec for: <your feature description>" -ForegroundColor Gray
Write-Host ""
Write-Host "  📖 Full guide: See ONBOARDING.md in the accelerator repo" -ForegroundColor White
Write-Host ""
