#!/usr/bin/env bash
# =============================================================================
# skills.sh — DevelopersCoffee / Airo agent skill installer
# =============================================================================
#
# Installs (or updates) all DevelopersCoffee design and agent skills into the
# AI agent skills directory on your local machine.
#
# Supported agents:
#   --claude   → ~/.claude/skills/          (Claude Code / Anthropic)
#   --antigravity → ~/.gemini/config/       (Google Antigravity / AGY)
#   --all      → both of the above (default)
#
# Usage:
#   ./skills.sh               # install/update for all agents
#   ./skills.sh --claude      # Claude Code only
#   ./skills.sh --antigravity # Antigravity only
#   ./skills.sh --list        # show available skills without installing
#   ./skills.sh --help        # show this help
#
# Skills are sourced from:
#   1. .claude/skills/  inside this repo      (project-bundled skills)
#   2. DevelopersCoffee/10-foot-design repo   (TV design skill)
#
# Requirements: git, bash 3.2+
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✅  $*${RESET}"; }
info() { echo -e "${CYAN}ℹ️   $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️   $*${RESET}"; }
err()  { echo -e "${RED}❌  $*${RESET}" >&2; }
h1()   { echo -e "\n${BOLD}$*${RESET}"; }

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_SKILLS_DIR="$REPO_ROOT/.claude/skills"

CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
ANTIGRAVITY_SKILLS_DIR="$HOME/.gemini/config/skills"

TV_DESIGN_REPO="git@github.com:DevelopersCoffee/10-foot-design.git"
TV_DESIGN_LOCAL="$HOME/.cache/developerscoffee/10-foot-design"
TV_DESIGN_SKILL_NAME="android-tv-design"

# ── Arg parsing ───────────────────────────────────────────────────────────────
DO_CLAUDE=true
DO_ANTIGRAVITY=true
LIST_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --claude)       DO_ANTIGRAVITY=false ;;
    --antigravity)  DO_CLAUDE=false ;;
    --all)          DO_CLAUDE=true; DO_ANTIGRAVITY=true ;;
    --list)         LIST_ONLY=true ;;
    --help|-h)
      sed -n '/^# =/,/^# =/p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    *)
      err "Unknown argument: $arg"
      echo "Run './skills.sh --help' for usage."
      exit 1 ;;
  esac
done

# ── Helper: install one skill dir into a target skills dir ────────────────────
install_skill() {
  local skill_src="$1"   # absolute path to skill folder
  local target_dir="$2"  # e.g. ~/.claude/skills
  local skill_name
  skill_name="$(basename "$skill_src")"
  local dest="$target_dir/$skill_name"

  mkdir -p "$target_dir"

  if [ -L "$dest" ]; then
    info "$skill_name → symlink already exists, skipping"
    return
  fi

  if [ -d "$dest" ]; then
    # Overwrite / update
    rm -rf "$dest"
    cp -r "$skill_src" "$dest"
    ok "$skill_name updated in $(basename "$target_dir")"
  else
    cp -r "$skill_src" "$dest"
    ok "$skill_name installed into $(basename "$target_dir")"
  fi
}

# ── Ensure 10-foot-design repo is available locally ──────────────────────────
ensure_tv_design_repo() {
  if [ -d "$TV_DESIGN_LOCAL/.git" ]; then
    info "Updating 10-foot-design …"
    git -C "$TV_DESIGN_LOCAL" pull --ff-only --quiet \
      && ok "10-foot-design up to date" \
      || warn "Could not pull 10-foot-design (offline?). Using cached copy."
  else
    info "Cloning DevelopersCoffee/10-foot-design …"
    mkdir -p "$(dirname "$TV_DESIGN_LOCAL")"
    git clone --depth 1 "$TV_DESIGN_REPO" "$TV_DESIGN_LOCAL" --quiet \
      && ok "10-foot-design cloned" \
      || { err "Clone failed. Check SSH key / network."; exit 1; }
  fi
}

# ── Collect all skills ────────────────────────────────────────────────────────
collect_skills() {
  # 1. Skills bundled in this repo
  local bundled=()
  if [ -d "$REPO_SKILLS_DIR" ]; then
    for d in "$REPO_SKILLS_DIR"/*/; do
      [ -d "$d" ] && bundled+=("$d")
    done
  fi

  # 2. TV design skill from external repo
  local tv_skill="$TV_DESIGN_LOCAL/skills/$TV_DESIGN_SKILL_NAME"
  local external=()
  [ -d "$tv_skill" ] && external+=("$tv_skill")

  ALL_SKILLS=("${bundled[@]}" "${external[@]}")
}

# ── List mode ─────────────────────────────────────────────────────────────────
if $LIST_ONLY; then
  ensure_tv_design_repo
  collect_skills
  h1 "Available DevelopersCoffee skills"
  for s in "${ALL_SKILLS[@]}"; do
    name="$(basename "$s")"
    desc=""
    if [ -f "$s/SKILL.md" ]; then
      # Pull description from YAML front-matter
      desc=$(awk '/^description:/{sub(/^description: */,""); print; exit}' "$s/SKILL.md")
    fi
    printf "  ${CYAN}%-32s${RESET} %s\n" "$name" "$desc"
  done
  echo ""
  exit 0
fi

# ── Main install ──────────────────────────────────────────────────────────────
h1 "DevelopersCoffee / Airo — Skill Installer"
echo "  Repo: $REPO_ROOT"
echo "  Date: $(date '+%Y-%m-%d %H:%M')"
echo ""

ensure_tv_design_repo
collect_skills

if [ ${#ALL_SKILLS[@]} -eq 0 ]; then
  warn "No skills found to install."
  exit 0
fi

if $DO_CLAUDE; then
  h1 "Installing into Claude Code  ($CLAUDE_SKILLS_DIR)"
  for skill in "${ALL_SKILLS[@]}"; do
    install_skill "$skill" "$CLAUDE_SKILLS_DIR"
  done
fi

if $DO_ANTIGRAVITY; then
  h1 "Installing into Antigravity  ($ANTIGRAVITY_SKILLS_DIR)"
  for skill in "${ALL_SKILLS[@]}"; do
    install_skill "$skill" "$ANTIGRAVITY_SKILLS_DIR"
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
h1 "Done ✨"
echo ""
echo "  Skills installed:"
for skill in "${ALL_SKILLS[@]}"; do
  printf "    • %s\n" "$(basename "$skill")"
done
echo ""

if $DO_CLAUDE; then
  echo "  Claude Code:    ls ~/.claude/skills/"
fi
if $DO_ANTIGRAVITY; then
  echo "  Antigravity:    ls ~/.gemini/config/skills/"
fi
echo ""
echo "  Verify in Claude Code:"
echo "    → Open this project, then ask:"
echo "      'review HomeScreen.kt against android-tv-design skill'"
echo "      'build a Browse screen using android-tv-design layout specs'"
echo ""
echo "  To keep skills updated, re-run:"
echo "    ./scripts/skills.sh"
echo ""
