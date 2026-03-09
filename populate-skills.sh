#!/bin/bash
# ============================================================================
# populate-skills.sh — Clone open-source skill repos and copy into this library
#
# ⚠️  SECURITY NOTE: Review each skill's SKILL.md and scripts/ folder
#     for security issues before committing to your repo.
#
# Run ONCE to populate all .gitkeep placeholder folders with real skills.
# After running, review what was copied, then: git add . && git commit
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="/tmp/skill-sources"
mkdir -p "$SRC"

echo "════════════════════════════════════════════════════════════"
echo "  Populating Skills Library from Open Source Repos"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  Review each skill for security before committing!"
echo ""

# ── Clone all source repos ───────────────────────────────────────────────────
echo "Step 1/3: Cloning source repositories..."
echo "──────────────────────────────────────────"

clone_if_missing() {
    local url="$1"
    local dest="$2"
    if [ -d "$dest" ]; then
        echo "  ⏭  Already cloned: $(basename "$dest")"
    else
        echo "  📦 Cloning: $url"
        git clone --depth 1 "$url" "$dest" 2>/dev/null || echo "  ⚠️  Failed to clone: $url"
    fi
}

# Product skills sources
clone_if_missing "https://github.com/OthmanAdi/planning-with-files.git"         "$SRC/planning"
clone_if_missing "https://github.com/deanpeters/Product-Manager-Skills.git"     "$SRC/pm-skills"
clone_if_missing "https://github.com/levnikolaevich/claude-code-skills.git"     "$SRC/delivery"
clone_if_missing "https://github.com/automazeio/ccpm.git"                       "$SRC/ccpm"

# UI/UX skills sources
clone_if_missing "https://github.com/addyosmani/web-quality-skills.git"         "$SRC/webquality"

# Frontend skills sources
clone_if_missing "https://github.com/dralgorhythm/claude-agentic-framework.git" "$SRC/framework"
clone_if_missing "https://github.com/lackeyjb/playwright-skill.git"             "$SRC/playwright"

# Backend skills sources
clone_if_missing "https://github.com/Jeffallan/claude-skills.git"               "$SRC/jeffallan"
clone_if_missing "https://github.com/decebals/claude-code-java.git"             "$SRC/java"
clone_if_missing "https://github.com/giuseppe-trisciuoglio/developer-kit.git"    "$SRC/devkit"

# Platform skills sources
clone_if_missing "https://github.com/aidankinzett/claude-git-pr-skill.git"      "$SRC/pr"
clone_if_missing "https://github.com/hashicorp/agent-skills.git"                "$SRC/hashicorp"
clone_if_missing "https://github.com/snyk/studio-recipes.git"                   "$SRC/snyk"
clone_if_missing "https://github.com/snyk-labs/snyk-learning-path-skill.git"    "$SRC/snyklearn"
clone_if_missing "https://github.com/wshobson/agents.git"                       "$SRC/wshobson"

# Marketing skills sources
clone_if_missing "https://github.com/AgriciDaniel/claude-seo.git"               "$SRC/claude-seo"
clone_if_missing "https://github.com/smixs/creative-director-skill.git"         "$SRC/creative-director"

echo ""

# ── Copy skills into domain folders ──────────────────────────────────────────
echo "Step 2/3: Copying skills into domain folders..."
echo "──────────────────────────────────────────"

copy_skill() {
    local src_path="$1"
    local dest_path="$2"
    local skill_name
    skill_name=$(basename "$dest_path")

    if [ -d "$src_path" ]; then
        # Remove .gitkeep, copy content
        rm -f "$dest_path/.gitkeep" 2>/dev/null
        cp -r "$src_path"/* "$dest_path/" 2>/dev/null || cp -r "$src_path"/. "$dest_path/" 2>/dev/null
        echo "  ✓ $skill_name"
    else
        echo "  ⚠️  Source not found: $src_path (keeping placeholder)"
    fi
}

# ── PRODUCT-SKILLS ──
echo ""
echo "  product-skills/"
# Note: Exact source paths may vary — check each repo's structure
copy_skill "$SRC/planning"                                                        "$REPO_ROOT/product-skills/skills/planning-with-files"
# Dean Peters PM skills — check for skills/ or .claude/skills/ subfolder
for skill in prd-development user-story epic-hypothesis prioritization-advisor roadmap-planning discovery-interview-prep positioning-statement; do
    for src_try in "$SRC/pm-skills/skills/$skill" "$SRC/pm-skills/.claude/skills/$skill" "$SRC/pm-skills/$skill"; do
        if [ -d "$src_try" ]; then
            copy_skill "$src_try" "$REPO_ROOT/product-skills/skills/$skill"
            break
        fi
    done
done
# Levnikolaevich delivery skills (non-standard naming: ln-NNN-skill-name)
copy_skill "$SRC/delivery/ln-210-epic-coordinator" "$REPO_ROOT/product-skills/skills/epic-coordinator"
for skill in scope-decomposer; do
    for src_try in "$SRC/delivery/skills/$skill" "$SRC/delivery/.claude/skills/$skill"; do
        if [ -d "$src_try" ]; then
            copy_skill "$src_try" "$REPO_ROOT/product-skills/skills/$skill"
            break
        fi
    done
done
# CCPM
for src_try in "$SRC/ccpm/skills/prd-to-epic-pipeline" "$SRC/ccpm/.claude/skills/prd-to-epic-pipeline"; do
    if [ -d "$src_try" ]; then
        copy_skill "$src_try" "$REPO_ROOT/product-skills/skills/prd-to-epic-pipeline"
        break
    fi
done

# ── UIUX-SKILLS ──
echo ""
echo "  uiux-skills/"
for skill in accessibility best-practices; do
    for src_try in "$SRC/webquality/skills/$skill" "$SRC/webquality/.claude/skills/$skill"; do
        if [ -d "$src_try" ]; then
            copy_skill "$src_try" "$REPO_ROOT/uiux-skills/skills/$skill"
            break
        fi
    done
done
# Framework design skills (different names in source)
copy_skill "$SRC/framework/.claude/skills/product/brainstorming"      "$REPO_ROOT/uiux-skills/skills/brainstorming"
copy_skill "$SRC/framework/.claude/skills/design/interface-design"    "$REPO_ROOT/uiux-skills/skills/platform-design"
copy_skill "$SRC/framework/.claude/skills/design/design-systems"      "$REPO_ROOT/uiux-skills/skills/design-md"

# ── FRONTEND-SKILLS ──
echo ""
echo "  frontend-skills/"
for skill in performance core-web-vitals seo; do
    for src_try in "$SRC/webquality/skills/$skill" "$SRC/webquality/.claude/skills/$skill"; do
        if [ -d "$src_try" ]; then
            copy_skill "$src_try" "$REPO_ROOT/frontend-skills/skills/$skill"
            break
        fi
    done
done
for skill in test-driven-development implementing-code; do
    for src_try in "$SRC/framework/.claude/skills/core-engineering/$skill" "$SRC/framework/skills/$skill"; do
        if [ -d "$src_try" ]; then
            copy_skill "$src_try" "$REPO_ROOT/frontend-skills/skills/$skill"
            break
        fi
    done
done
for src_try in "$SRC/playwright/skills/playwright-skill" "$SRC/playwright/.claude/skills/playwright-skill" "$SRC/playwright"; do
    if [ -d "$src_try" ] && [ -f "$src_try/SKILL.md" ]; then
        copy_skill "$src_try" "$REPO_ROOT/frontend-skills/skills/playwright-skill"
        break
    fi
done
# Jeffallan skills (different names in source → our names)
copy_skill "$SRC/jeffallan/skills/react-expert"    "$REPO_ROOT/frontend-skills/skills/react-best-practices"
copy_skill "$SRC/jeffallan/skills/test-master"      "$REPO_ROOT/frontend-skills/skills/webapp-testing"
# wshobson responsive design → frontend-design
copy_skill "$SRC/wshobson/plugins/ui-design/skills/responsive-design" "$REPO_ROOT/frontend-skills/skills/frontend-design"

# ── BACKEND-SKILLS ──
echo ""
echo "  backend-skills/"
for src_try in "$SRC/jeffallan/skills/java-architect" "$SRC/jeffallan/.claude/skills/java-architect"; do
    if [ -d "$src_try" ]; then
        copy_skill "$src_try" "$REPO_ROOT/backend-skills/skills/java-architect"
        break
    fi
done
# Decebals Java skills — copy all available
if [ -d "$SRC/java/.claude/skills" ]; then
    for skill_dir in "$SRC/java/.claude/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        if [ -d "$REPO_ROOT/backend-skills/skills/$skill_name" ]; then
            copy_skill "$skill_dir" "$REPO_ROOT/backend-skills/skills/$skill_name"
        fi
    done
elif [ -d "$SRC/java/skills" ]; then
    for skill_dir in "$SRC/java/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        if [ -d "$REPO_ROOT/backend-skills/skills/$skill_name" ]; then
            copy_skill "$skill_dir" "$REPO_ROOT/backend-skills/skills/$skill_name"
        fi
    done
fi
# Framework engineering skills
for skill in debugging refactoring-code dependency-management optimizing-code; do
    for src_try in "$SRC/framework/.claude/skills/core-engineering/$skill" "$SRC/framework/skills/$skill"; do
        if [ -d "$src_try" ]; then
            copy_skill "$src_try" "$REPO_ROOT/backend-skills/skills/$skill"
            break
        fi
    done
done
# Jeffallan skills (different names → our backend skill names)
copy_skill "$SRC/jeffallan/skills/postgres-pro"           "$REPO_ROOT/backend-skills/skills/postgresql"
copy_skill "$SRC/jeffallan/skills/database-optimizer"     "$REPO_ROOT/backend-skills/skills/databases"
copy_skill "$SRC/jeffallan/skills/architecture-designer"  "$REPO_ROOT/backend-skills/skills/software-architecture"
copy_skill "$SRC/jeffallan/skills/code-reviewer"          "$REPO_ROOT/backend-skills/skills/code-quality-checker"
copy_skill "$SRC/jeffallan/skills/test-master"            "$REPO_ROOT/backend-skills/skills/test-executor"

# ── PLATFORM-SKILLS ──
echo ""
echo "  platform-skills/"
# PR skill (nested structure: github-pr-review/skills/github-pr-review/)
copy_skill "$SRC/pr/github-pr-review/skills/github-pr-review" "$REPO_ROOT/platform-skills/skills/github-pr-review"
for src_try in "$SRC/jeffallan/skills/devops-engineer" "$SRC/jeffallan/.claude/skills/devops-engineer"; do
    if [ -d "$src_try" ]; then
        copy_skill "$src_try" "$REPO_ROOT/platform-skills/skills/devops-engineer"
        break
    fi
done
# HashiCorp Terraform skills
for skill in terraform-style-guide terraform-test; do
    for src_try in "$SRC/hashicorp/terraform/code-generation/skills/$skill" "$SRC/hashicorp/skills/$skill"; do
        if [ -d "$src_try" ]; then
            copy_skill "$src_try" "$REPO_ROOT/platform-skills/skills/$skill"
            break
        fi
    done
done
# Snyk skills
for src_try in "$SRC/snyk/command_directives/synchronous_remediation/claude_code/skills/snyk-fix" "$SRC/snyk/skills/snyk-fix"; do
    if [ -d "$src_try" ]; then
        copy_skill "$src_try" "$REPO_ROOT/platform-skills/skills/snyk-fix"
        break
    fi
done
for src_try in "$SRC/snyklearn/skills/snyk-learning-path" "$SRC/snyklearn/.claude/skills/snyk-learning-path"; do
    if [ -d "$src_try" ]; then
        copy_skill "$src_try" "$REPO_ROOT/platform-skills/skills/snyk-learning-path"
        break
    fi
done
# Framework security/architecture skills → platform-skills
copy_skill "$SRC/framework/.claude/skills/core-engineering/debugging"       "$REPO_ROOT/platform-skills/skills/systematic-debugging"
copy_skill "$SRC/framework/.claude/skills/architecture/defense-in-depth"    "$REPO_ROOT/platform-skills/skills/defense-in-depth"
copy_skill "$SRC/framework/.claude/skills/security/application-security"    "$REPO_ROOT/platform-skills/skills/owasp-security"
copy_skill "$SRC/framework/.claude/skills/security/security-review"         "$REPO_ROOT/platform-skills/skills/vibesec"
# wshobson agents (nested: plugins/<category>/skills/<name>/)
copy_skill "$SRC/wshobson/plugins/incident-response/skills/incident-runbook-templates" "$REPO_ROOT/platform-skills/skills/incident-runbook-templates"
copy_skill "$SRC/wshobson/plugins/cicd-automation/skills/github-actions-templates"     "$REPO_ROOT/platform-skills/skills/github-actions-templates"

# ── MARKETING-SKILLS ──
echo ""
echo "  marketing-skills/"
# claude-seo repo: skills are individual (seo-audit, seo-content, etc.)
copy_skill "$SRC/claude-seo/skills/seo-audit"                             "$REPO_ROOT/marketing-skills/skills/claude-seo"
# creative-director repo: non-standard structure (creative-director/SKILL.md at second level)
copy_skill "$SRC/creative-director/creative-director"                     "$REPO_ROOT/marketing-skills/skills/creative-director"

echo ""
echo "Step 3/3: Summary"
echo "──────────────────────────────────────────"
total_populated=0
total_placeholder=0
for domain in "$REPO_ROOT"/*-skills/; do
    [ ! -d "$domain/skills" ] && continue
    domain_name=$(basename "$domain")
    populated=0
    placeholder=0
    for skill in "$domain/skills"/*/; do
        [ ! -d "$skill" ] && continue
        count=$(find "$skill" -not -name '.gitkeep' -not -path "$skill" | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            ((populated++))
        else
            ((placeholder++))
        fi
    done
    echo "  $domain_name: $populated populated, $placeholder placeholders"
    total_populated=$((total_populated + populated))
    total_placeholder=$((total_placeholder + placeholder))
done
echo ""
echo "Total: $total_populated populated, $total_placeholder remaining placeholders"
echo ""
echo "⚠️  NEXT STEPS:"
echo "  1. Review each copied skill's SKILL.md and scripts/ for security"
echo "  2. git add . && git commit -m 'feat: populate open-source skills'"
echo "  3. Run ./sync-platforms.sh to create IDE symlinks"
