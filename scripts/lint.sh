#!/usr/bin/env bash
set -euo pipefail

# SwiftLint script for SwiftProjectTemplate projects
# Runs SwiftLint with optional auto-fixing

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
FIX_ISSUES=false
STRICT_MODE=false
QUIET_MODE=false

show_help() {
  cat <<EOF
SwiftLint Script

Runs SwiftLint to check code style and quality issues with optional auto-fixing.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --fix                    Auto-fix issues where possible
  --strict                 Treat warnings as errors
  --quiet                  Show only errors (suppress warnings)
  --help                   Show this help message

EXAMPLES:
  $0                       # Check code style
  $0 --fix                 # Check and auto-fix issues
  $0 --strict              # Treat warnings as errors
  $0 --fix --strict        # Auto-fix and be strict about remaining issues

CONFIGURATION:
  SwiftLint configuration is read from .swiftlint.yml in the project root.
  
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --fix)
        FIX_ISSUES=true
        shift
        ;;
      --strict)
        STRICT_MODE=true
        shift
        ;;
      --quiet)
        QUIET_MODE=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
      *)
        log_error "Unexpected argument: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
    esac
  done
}

check_swiftlint_config() {
  local config_file=".swiftlint.yml"
  
  if [[ ! -f "$config_file" ]]; then
    log_warning "SwiftLint configuration not found: $config_file"
    log_info "Using SwiftLint default rules"
    return
  fi
  
  # Validate YAML syntax
  if command_exists yq; then
    if ! yq eval '.' "$config_file" >/dev/null 2>&1; then
      log_error "Invalid YAML syntax in $config_file"
      exit 1
    fi
  fi
  
  log_info "Using SwiftLint configuration: $config_file"
}

get_source_directories() {
  local source_dirs=()
  
  if [[ -f "project.yml" && command_exists yq ]]; then
    local project_name
    project_name=$(yq eval '.name' project.yml 2>/dev/null || echo "")
    
    if [[ -n "$project_name" && "$project_name" != "null" ]]; then
      # Add main source directory if it exists
      if [[ -d "$project_name" ]]; then
        source_dirs+=("$project_name")
      fi
      
      # Add test directories if they exist
      if [[ -d "${project_name}Tests" ]]; then
        source_dirs+=("${project_name}Tests")
      fi
      
      if [[ -d "${project_name}UITests" ]]; then
        source_dirs+=("${project_name}UITests")
      fi
    fi
  fi
  
  # Fallback: look for common Swift source directories
  if [[ ${#source_dirs[@]} -eq 0 ]]; then
    for dir in Sources App Tests; do
      if [[ -d "$dir" ]]; then
        source_dirs+=("$dir")
      fi
    done
  fi
  
  # If still no directories found, lint current directory
  if [[ ${#source_dirs[@]} -eq 0 ]]; then
    source_dirs+=(".")
  fi
  
  echo "${source_dirs[@]}"
}

run_swiftlint() {
  local source_dirs
  read -a source_dirs <<< "$(get_source_directories)"
  
  log_info "SwiftLint directories: ${source_dirs[*]}"
  
  # Prepare SwiftLint arguments
  local swiftlint_args=()
  
  if $FIX_ISSUES; then
    swiftlint_args+=("--fix")
    log_info "Running SwiftLint with auto-fix enabled..."
  else
    swiftlint_args+=("lint")
    log_info "Running SwiftLint check..."
  fi
  
  if $STRICT_MODE; then
    swiftlint_args+=("--strict")
  fi
  
  if $QUIET_MODE; then
    swiftlint_args+=("--quiet")
  fi
  
  # Add source directories
  for dir in "${source_dirs[@]}"; do
    swiftlint_args+=("$dir")
  done
  
  # Run SwiftLint
  local start_time
  start_time=$(date +%s)
  
  if swiftlint "${swiftlint_args[@]}"; then
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if $FIX_ISSUES; then
      log_success "SwiftLint auto-fix completed in ${duration}s"
    else
      log_success "SwiftLint check passed in ${duration}s"
    fi
  else
    local exit_code=$?
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if $FIX_ISSUES; then
      log_warning "SwiftLint auto-fix completed with issues in ${duration}s"
      log_info "Some issues may require manual attention"
    else
      if $STRICT_MODE; then
        log_error "SwiftLint check failed (strict mode) in ${duration}s"
      else
        log_warning "SwiftLint check found issues in ${duration}s"
      fi
    fi
    
    return $exit_code
  fi
}

show_lint_summary() {
  echo
  if $FIX_ISSUES; then
    log_info "SwiftLint auto-fix summary:"
    echo "  • Automatically fixable issues have been resolved"
    echo "  • Review the changes and run again to check for remaining issues"
    echo "  • Some complex issues may require manual fixes"
  else
    log_info "SwiftLint check summary:"
    echo "  • Run with --fix to automatically resolve fixable issues"
    echo "  • Check .swiftlint.yml to customize rules"
    echo "  • Some rules may require code refactoring"
  fi
  
  echo
  log_info "Next steps:"
  if $FIX_ISSUES; then
    echo "  • Review changes: git diff"
    echo "  • Run lint check: ./scripts/lint.sh"
    echo "  • Format code: ./scripts/format.sh --fix"
  else
    echo "  • Fix issues: ./scripts/lint.sh --fix"
    echo "  • Format code: ./scripts/format.sh"
    echo "  • Full check: ./scripts/preflight.sh"
  fi
}

# Main execution
main() {
  log_info "SwiftLint Code Quality Check"
  echo
  
  parse_arguments "$@"
  
  if ! check_required_tools swiftlint; then
    log_error "SwiftLint is not installed"
    log_info "Install with: brew install swiftlint"
    exit 1
  fi
  
  check_swiftlint_config
  
  if run_swiftlint; then
    show_lint_summary
    exit 0
  else
    local exit_code=$?
    show_lint_summary
    exit $exit_code
  fi
}

# Run main function with all arguments
main "$@"