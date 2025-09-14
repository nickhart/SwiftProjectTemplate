#!/usr/bin/env bash
set -euo pipefail

# SwiftFormat script for SwiftProjectTemplate projects
# Runs SwiftFormat to check and fix code formatting

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
FIX_ISSUES=false
CHECK_ONLY=true
VERBOSE=false

show_help() {
  cat <<EOF
SwiftFormat Script

Runs SwiftFormat to check and fix code formatting issues.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --fix                    Auto-fix formatting issues (default: check only)
  --verbose                Show verbose output
  --help                   Show this help message

EXAMPLES:
  $0                       # Check formatting only
  $0 --fix                 # Check and auto-fix formatting issues
  $0 --fix --verbose       # Fix with verbose output

CONFIGURATION:
  SwiftFormat configuration is read from .swiftformat in the project root.

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --fix)
        FIX_ISSUES=true
        CHECK_ONLY=false
        shift
        ;;
      --verbose)
        VERBOSE=true
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

check_swiftformat_config() {
  local config_file=".swiftformat"

  if [[ ! -f "$config_file" ]]; then
    log_warning "SwiftFormat configuration not found: $config_file"
    log_info "Using SwiftFormat default settings"
    return
  fi

  log_info "Using SwiftFormat configuration: $config_file"
}

get_source_directories() {
  local source_dirs=()

  if [[ -f "project.yml" ]] && command_exists yq ; then
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

  # If still no directories found, format current directory
  if [[ ${#source_dirs[@]} -eq 0 ]]; then
    source_dirs+=(".")
  fi

  echo "${source_dirs[@]}"
}

run_swiftformat() {
  local source_dirs
  read -a source_dirs <<< "$(get_source_directories)"

  log_info "SwiftFormat directories: ${source_dirs[*]}"

  # Prepare SwiftFormat arguments (directories first, then options)
  local swiftformat_args=()

  # Add source directories first
  for dir in "${source_dirs[@]}"; do
    swiftformat_args+=("$dir")
  done

  if $CHECK_ONLY; then
    swiftformat_args+=("--lint")
    log_info "Running SwiftFormat check..."
  else
    log_info "Running SwiftFormat with auto-fix enabled..."
  fi

  if $VERBOSE; then
    swiftformat_args+=("--verbose")
  fi

  # Run SwiftFormat
  local start_time
  start_time=$(date +%s)

  local exit_code=0
  if swiftformat "${swiftformat_args[@]}"; then
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if $CHECK_ONLY; then
      log_success "SwiftFormat check passed in ${duration}s"
    else
      log_success "SwiftFormat auto-fix completed in ${duration}s"
    fi
  else
    exit_code=$?
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if $CHECK_ONLY; then
      log_warning "SwiftFormat check found formatting issues in ${duration}s"
    else
      log_error "SwiftFormat encountered errors in ${duration}s"
    fi
  fi

  return $exit_code
}

show_format_summary() {
  echo
  if $CHECK_ONLY; then
    log_info "SwiftFormat check summary:"
    echo "  • Run with --fix to automatically resolve formatting issues"
    echo "  • Check .swiftformat to customize formatting rules"
    echo "  • All formatting issues can be automatically fixed"
  else
    log_info "SwiftFormat auto-fix summary:"
    echo "  • All formatting issues have been automatically resolved"
    echo "  • Review the changes before committing"
    echo "  • Consider running SwiftLint for additional code quality checks"
  fi

  echo
  log_info "Next steps:"
  if $CHECK_ONLY; then
    echo "  • Fix formatting: ./scripts/format.sh --fix"
    echo "  • Check linting: ./scripts/lint.sh"
    echo "  • Full check: ./scripts/preflight.sh"
  else
    echo "  • Review changes: git diff"
    echo "  • Run linting: ./scripts/lint.sh"
    echo "  • Run tests: ./scripts/test.sh"
  fi
}

# Main execution
main() {
  log_info "SwiftFormat Code Formatting"
  echo

  parse_arguments "$@"

  if ! check_required_tools swiftformat; then
    log_error "SwiftFormat is not installed"
    log_info "Install with: brew install swiftformat"
    exit 1
  fi

  check_swiftformat_config

  if run_swiftformat; then
    show_format_summary
    exit 0
  else
    local exit_code=$?
    show_format_summary
    exit $exit_code
  fi
}

# Run main function with all arguments
main "$@"