#!/usr/bin/env bash
set -euo pipefail

# Pre-commit hook for SwiftProjectTemplate projects
# Runs formatting, linting, and basic validation before allowing commits

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Configuration
AUTO_FIX=true
ALLOW_WARNINGS=true

log_info "🔍 Running pre-commit checks..."
echo

# Check if we have any Swift files to process
get_staged_swift_files() {
  git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true
}

staged_files=$(get_staged_swift_files)

if [[ -z "$staged_files" ]]; then
  log_info "No Swift files staged for commit, skipping Swift-specific checks"
  exit 0
fi

log_info "Staged Swift files:"
echo "$staged_files" | sed 's/^/  • /'
echo

# Function to check if tools are available
check_tools() {
  local missing_tools=()

  for tool in swiftformat swiftlint; do
    if ! command_exists "$tool"; then
      missing_tools+=("$tool")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_warning "Missing tools: ${missing_tools[*]}"
    log_info "Install with: brew bundle install"
    log_info "Skipping pre-commit checks"
    exit 0
  fi
}

# Run SwiftFormat on staged files
run_swiftformat() {
  log_info "📝 Running SwiftFormat..."

  local format_failed=false

  if $AUTO_FIX; then
    # Format staged files
    echo "$staged_files" | while read -r file; do
      if [[ -f "$file" ]]; then
        swiftformat "$file"
      fi
    done

    # Check if any files were modified
    local modified_files
    modified_files=$(echo "$staged_files" | xargs git diff --name-only 2>/dev/null || true)

    if [[ -n "$modified_files" ]]; then
      log_info "SwiftFormat made changes to:"
      echo "$modified_files" | sed 's/^/  • /'

      # Re-stage the formatted files
      echo "$modified_files" | xargs git add

      log_success "Formatted files re-staged for commit"
    else
      log_success "No formatting changes needed"
    fi
  else
    # Check formatting without fixing
    local format_issues=""
    echo "$staged_files" | while read -r file; do
      if [[ -f "$file" ]]; then
        if ! swiftformat --lint "$file" >/dev/null 2>&1; then
          format_issues="$format_issues$file "
        fi
      fi
    done

    if [[ -n "$format_issues" ]]; then
      log_error "SwiftFormat issues found in: $format_issues"
      log_info "Fix with: ./scripts/format.sh --fix"
      format_failed=true
    else
      log_success "SwiftFormat check passed"
    fi
  fi

  if $format_failed; then
    return 1
  fi
}

# Run SwiftLint on staged files
run_swiftlint() {
  log_info "🔍 Running SwiftLint..."

  local lint_failed=false
  local temp_file=$(mktemp)

  # Create temporary file with staged file list
  echo "$staged_files" > "$temp_file"

  if swiftlint lint < "$temp_file" 2>&1; then
    log_success "SwiftLint check passed"
  else
    local exit_code=$?

    if $ALLOW_WARNINGS && [[ $exit_code -eq 2 ]]; then
      log_warning "SwiftLint found warnings (allowing commit)"
    else
      log_error "SwiftLint found errors"
      log_info "Fix with: ./scripts/lint.sh --fix"
      lint_failed=true
    fi
  fi

  rm -f "$temp_file"

  if $lint_failed; then
    return 1
  fi
}

# Check for common issues
run_basic_checks() {
  log_info "✅ Running basic checks..."

  local issues=()

  # Check for TODO/FIXME in staged files (informational)
  local todo_count=0
  echo "$staged_files" | while read -r file; do
    if [[ -f "$file" ]]; then
      local file_todos
      file_todos=$(grep -n "TODO\|FIXME" "$file" 2>/dev/null || true)
      if [[ -n "$file_todos" ]]; then
        todo_count=$((todo_count + 1))
      fi
    fi
  done

  if [[ $todo_count -gt 0 ]]; then
    log_info "Found TODO/FIXME comments in $todo_count file(s) (informational)"
  fi

  # Check for debug prints (warning)
  local debug_prints=()
  echo "$staged_files" | while read -r file; do
    if [[ -f "$file" ]]; then
      if grep -q "print(" "$file" 2>/dev/null; then
        debug_prints+=("$file")
      fi
    fi
  done

  if [[ ${#debug_prints[@]} -gt 0 ]]; then
    log_warning "Found print() statements in:"
    printf '%s\n' "${debug_prints[@]}" | sed 's/^/  • /'
    log_info "Consider removing debug prints before committing"
  fi

  log_success "Basic checks completed"
}

# Main execution
main() {
  check_tools

  local checks_failed=false

  # Run all checks
  if ! run_swiftformat; then
    checks_failed=true
  fi

  if ! run_swiftlint; then
    checks_failed=true
  fi

  run_basic_checks

  echo
  if $checks_failed; then
    log_error "❌ Pre-commit checks failed"
    log_info "Fix the issues above and try committing again"
    log_info "Or use 'git commit --no-verify' to skip these checks"
    exit 1
  else
    log_success "✅ Pre-commit checks passed"
    log_info "Proceeding with commit..."
  fi
}

# Run main function
main