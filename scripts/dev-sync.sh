#!/usr/bin/env bash
set -euo pipefail

# Development sync script for SwiftProjectTemplate
# MUST be run from the root of the SwiftProjectTemplate repository

source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Configuration
SYNC_MODE=""
TARGET_PROJECT=""
DRY_RUN=false
FORCE_SYNC=false

show_help() {
  cat <<EOF
Template Development Sync Script

Simple rsync wrapper for syncing template files between the template repository and test projects.
IMPORTANT: This script must be run from the SwiftProjectTemplate root directory.

USAGE:
  $0 <MODE> <TARGET_PROJECT> [OPTIONS]

MODES:
  to <project>             Sync template changes TO test project
  from <project>           Sync fixes FROM test project back to template
  diff <project>           Show differences between template and project

OPTIONS:
  --dry-run               Show what would be synced without making changes
  --force                 Force overwrite (ignore timestamps)
  --help                  Show this help message

EXAMPLES:
  # From SwiftProjectTemplate directory:
  $0 to ../MyTestApp
  $0 from ../MyTestApp --dry-run
  $0 diff ../MyTestApp

SYNCABLE ITEMS:
  • scripts/, templates/, .github/, .vscode/
  • Brewfile, .swift-version, .markdownlint.json
  • TODO.md, IMPLEMENTATION_PLAN.md

EOF
}

parse_arguments() {
  if [[ $# -lt 2 ]]; then
    show_help
    exit 1
  fi

  SYNC_MODE="$1"
  TARGET_PROJECT="$2"
  shift 2

  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force)
        FORCE_SYNC=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
      *)
        log_error "Unexpected argument: $1"
        exit 1
        ;;
    esac
  done

  # Validate mode
  case "$SYNC_MODE" in
    to|from|diff)
      ;;
    *)
      log_error "Invalid mode: $SYNC_MODE"
      log_info "Valid modes: to, from, diff"
      exit 1
      ;;
  esac
}

check_template_repo_root() {
  if [[ ! -f "scripts/setup.sh" || ! -f "IMPLEMENTATION_PLAN.md" || ! -d "templates" ]]; then
    log_error "This script must be run from the SwiftProjectTemplate root directory"
    exit 1
  fi
  log_info "✓ Running from template repository root"
}

validate_target_project() {
  if [[ ! -d "$TARGET_PROJECT" ]]; then
    log_error "Target project directory not found: $TARGET_PROJECT"
    exit 1
  fi
  log_info "✓ Target project validated: $TARGET_PROJECT"
}

# Build rsync command with common options
build_rsync_cmd() {
  local rsync_cmd=("rsync")
  
  # Always use these options
  rsync_cmd+=("-av")  # archive + verbose
  
  # Conditional options
  if $DRY_RUN; then
    rsync_cmd+=("--dry-run")
  fi
  
  if ! $FORCE_SYNC; then
    rsync_cmd+=("-u")  # update (skip newer files)
  fi
  
  echo "${rsync_cmd[@]}"
}

sync_to_project() {
  log_info "Syncing template changes TO project: $TARGET_PROJECT"
  
  local rsync_cmd
  read -ra rsync_cmd <<< "$(build_rsync_cmd)"
  
  # Sync directories
  for dir in scripts templates .github .vscode; do
    if [[ -d "$dir" ]]; then
      "${rsync_cmd[@]}" "$dir/" "$TARGET_PROJECT/$dir/"
    fi
  done
  
  # Sync individual files
  for file in Brewfile .swift-version .markdownlint.json TODO.md IMPLEMENTATION_PLAN.md; do
    if [[ -f "$file" ]]; then
      "${rsync_cmd[@]}" "$file" "$TARGET_PROJECT/"
    fi
  done
  
  log_success "Sync to project complete"
}

sync_from_project() {
  log_info "Syncing changes FROM project back to template: $TARGET_PROJECT"
  
  local rsync_cmd
  read -ra rsync_cmd <<< "$(build_rsync_cmd)"
  
  # Sync directories (reverse direction)
  for dir in scripts templates .github .vscode; do
    if [[ -d "$TARGET_PROJECT/$dir" ]]; then
      "${rsync_cmd[@]}" "$TARGET_PROJECT/$dir/" "$dir/"
    fi
  done
  
  # Sync individual files (reverse direction)
  for file in Brewfile .swift-version .markdownlint.json TODO.md IMPLEMENTATION_PLAN.md; do
    if [[ -f "$TARGET_PROJECT/$file" ]]; then
      "${rsync_cmd[@]}" "$TARGET_PROJECT/$file" ./
    fi
  done
  
  log_success "Sync from project complete"
}

show_diff() {
  log_info "Showing differences between template and project: $TARGET_PROJECT"
  
  # Use rsync --dry-run to show what would be copied
  rsync -avcn --delete scripts/ templates/ .github/ .vscode/ Brewfile .swift-version .markdownlint.json TODO.md IMPLEMENTATION_PLAN.md "$TARGET_PROJECT/" 2>/dev/null || {
    log_info "Run with 'to' mode to see what files would be synced"
  }
}

# Main execution
main() {
  log_info "Template Development Sync"
  echo
  
  parse_arguments "$@"
  check_template_repo_root
  validate_target_project
  
  case "$SYNC_MODE" in
    to)
      sync_to_project
      ;;
    from)
      sync_from_project
      ;;
    diff)
      show_diff
      ;;
  esac
}

main "$@"