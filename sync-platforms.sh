#!/bin/bash
# ============================================================================
# sync-platforms.sh — Create symlinks from skills/ into each IDE's directory
#
# Finds all domain folders and symlinks each skill into:
#   .claude/skills/, .cursor/skills/, .codex/skills/, .gemini/skills/
#
# Usage:
#   ./sync-platforms.sh              # Sync all domains
#   ./sync-platforms.sh backend-skills  # Sync specific domain
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SPECIFIC_DOMAIN="${1:-}"
PLATFORMS=(".claude/skills" ".cursor/skills" ".codex/skills" ".gemini/skills")

sync_domain() {
    local domain_path="$1"
    local domain_name
    domain_name=$(basename "$domain_path")
    local skill_dir="$domain_path/skills"

    if [ ! -d "$skill_dir" ]; then
        return
    fi

    local linked=0
    for platform in "${PLATFORMS[@]}"; do
        local platform_dir="$domain_path/$platform"
        mkdir -p "$platform_dir"

        for skill in "$skill_dir"/*/; do
            [ ! -d "$skill" ] && continue
            local skill_name
            skill_name=$(basename "$skill")
            local link_target="$platform_dir/$skill_name"

            if [ ! -L "$link_target" ]; then
                ln -sf "../../skills/$skill_name" "$link_target"
                ((linked++))
            fi
        done
    done

    local skill_count
    skill_count=$(ls -1d "$skill_dir"/*/ 2>/dev/null | wc -l | tr -d ' ')
    echo "  $domain_name: $skill_count skills × ${#PLATFORMS[@]} platforms ($linked new links)"
}

echo "Syncing skills to all IDE platforms..."
echo "══════════════════════════════════════════"

if [ -n "$SPECIFIC_DOMAIN" ]; then
    if [ ! -d "$REPO_ROOT/$SPECIFIC_DOMAIN" ]; then
        echo "Error: Domain '$SPECIFIC_DOMAIN' not found."
        exit 1
    fi
    sync_domain "$REPO_ROOT/$SPECIFIC_DOMAIN"
else
    for domain in "$REPO_ROOT"/*/; do
        [ -d "$domain/skills" ] && sync_domain "$domain"
    done
fi

echo ""
echo "All platforms synced: .claude/ .cursor/ .codex/ .gemini/"
