#!/bin/bash
# ============================================================================
# install.sh — Install skills from this library into a target project
#
# Usage:
#   ./install.sh <DOMAIN> <TARGET_PATH> [SKILL_NAME]
#
# Examples:
#   ./install.sh backend-skills /path/to/my-project
#   ./install.sh backend-skills /path/to/my-project gradle-spring-conventions
#   ./install.sh frontend-skills . bff-patterns
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DOMAIN="${1:-}"
TARGET="${2:-.}"
SPECIFIC_SKILL="${3:-}"
PLATFORMS=(".claude/skills" ".cursor/skills" ".codex/skills" ".gemini/skills")

# ── Validate domain ──────────────────────────────────────────────────────────
if [ -z "$DOMAIN" ]; then
    echo "Usage: ./install.sh <DOMAIN> <TARGET_PATH> [SKILL_NAME]"
    echo ""
    echo "Available domains:"
    echo "─────────────────"
    for d in "$REPO_ROOT"/*/; do
        d_name=$(basename "$d")
        if [ -d "$d/skills" ]; then
            skill_count=$(ls -1d "$d/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
            echo "  $d_name ($skill_count skills)"
        fi
    done
    exit 1
fi

SKILL_DIR="$REPO_ROOT/$DOMAIN/skills"

if [ ! -d "$SKILL_DIR" ]; then
    echo "Error: Domain '$DOMAIN' not found."
    echo "Available domains:"
    for d in "$REPO_ROOT"/*/; do
        [ -d "$d/skills" ] && echo "  $(basename "$d")"
    done
    exit 1
fi

# ── Install specific skill ───────────────────────────────────────────────────
install_skill() {
    local skill_name="$1"
    local skill_path="$SKILL_DIR/$skill_name"

    if [ ! -d "$skill_path" ]; then
        echo "Error: Skill '$skill_name' not found in $DOMAIN."
        echo "Available skills:"
        ls -1 "$SKILL_DIR"
        exit 1
    fi

    # Skip empty placeholder dirs (only .gitkeep)
    local file_count
    file_count=$(find "$skill_path" -not -name '.gitkeep' -not -path "$skill_path" | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        echo "Warning: '$skill_name' is a placeholder (not yet populated). Skipping."
        return
    fi

    for platform in "${PLATFORMS[@]}"; do
        mkdir -p "$TARGET/$platform"
        cp -r "$skill_path" "$TARGET/$platform/"
    done
    echo "  ✓ Installed: $skill_name"
}

# ── Specific skill mode ──────────────────────────────────────────────────────
if [ -n "$SPECIFIC_SKILL" ]; then
    echo "Installing '$SPECIFIC_SKILL' from $DOMAIN → $TARGET"
    echo "────────────────────────────────────────────"
    install_skill "$SPECIFIC_SKILL"
    echo ""
    echo "Done. Skill available in: ${PLATFORMS[*]}"
    exit 0
fi

# ── Interactive mode ─────────────────────────────────────────────────────────
echo "Available skills in $DOMAIN:"
echo "────────────────────────────────────────────"
ls -1 "$SKILL_DIR"
echo ""
read -rp "Install ALL skills? (y/n): " ALL

if [ "$ALL" = "y" ] || [ "$ALL" = "Y" ]; then
    echo ""
    echo "Installing all skills from $DOMAIN → $TARGET"
    echo "────────────────────────────────────────────"
    installed=0
    skipped=0
    for skill in "$SKILL_DIR"/*/; do
        skill_name=$(basename "$skill")
        file_count=$(find "$skill" -not -name '.gitkeep' -not -path "$skill" | wc -l | tr -d ' ')
        if [ "$file_count" -eq 0 ]; then
            ((skipped++))
            continue
        fi
        for platform in "${PLATFORMS[@]}"; do
            mkdir -p "$TARGET/$platform"
            cp -r "$skill" "$TARGET/$platform/"
        done
        echo "  ✓ $skill_name"
        ((installed++))
    done
    echo ""
    echo "Summary: $installed installed, $skipped skipped (placeholders)"
else
    read -rp "Enter skill names (space-separated): " -a SELECTED
    echo ""
    echo "Installing selected skills → $TARGET"
    echo "────────────────────────────────────────────"
    for skill_name in "${SELECTED[@]}"; do
        install_skill "$skill_name"
    done
fi

echo ""
echo "Done. Skills available in: ${PLATFORMS[*]}"
