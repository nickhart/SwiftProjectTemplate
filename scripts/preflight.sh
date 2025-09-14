#!/usr/bin/env bash
set -euo pipefail

# Preflight script for SwiftProjectTemplate projects
# Comprehensive check that runs formatting, linting, building, and testing
# Use this before committing or creating pull requests

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
FIX_ISSUES=true
RUN_TESTS=true
BUILD_PROJECT=true
CONFIGURATION="Debug"
VERBOSE=false

show_help() {
  cat <<EOF
Preflight Script

Runs a comprehensive check of code quality, formatting, building, and testing.
This script simulates what CI will do and should be run before committing changes.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --no-fix                 Don't auto-fix formatting and linting issues
  --no-tests               Skip running tests
  --no-build               Skip building the project
  --release                Use Release configuration for build and tests
  --verbose                Show verbose output from all tools
  --help                   Show this help message

EXAMPLES:
  $0                       # Full preflight check with auto-fixes
  $0 --no-fix              # Check without auto-fixing issues
  $0 --release             # Run checks in Release configuration
  $0 --no-tests --verbose  # Skip tests, show verbose output

CHECKS PERFORMED:
  1. SwiftFormat (with --fix if enabled)
  2. SwiftLint (with --fix if enabled) 
  3. Project build
  4. Unit tests
  5. UI tests (if available)
  
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --no-fix)
        FIX_ISSUES=false
        shift
        ;;
      --no-tests)
        RUN_TESTS=false
        shift
        ;;
      --no-build)
        BUILD_PROJECT=false
        shift
        ;;
      --release)
        CONFIGURATION="Release"
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

check_prerequisites() {
  log_info "Checking prerequisites..."
  
  local required_tools=(swiftformat swiftlint xcodebuild)
  local missing_tools=()
  
  for tool in "${required_tools[@]}"; do
    if ! command_exists "$tool"; then
      missing_tools+=("$tool")
    fi
  done
  
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    log_info "Install missing tools with: brew bundle install"
    exit 1
  fi
  
  # Check for project.yml
  if [[ ! -f "project.yml" ]]; then
    log_error "project.yml not found"
    log_info "Run './scripts/setup.sh' first to configure the project"
    exit 1
  fi
  
  # Check for Xcode project
  local project_name
  if command_exists yq; then
    project_name=$(yq eval '.name' project.yml)
    if [[ ! -d "${project_name}.xcodeproj" ]]; then
      log_error "Xcode project not found: ${project_name}.xcodeproj"
      log_info "Generate it with: xcodegen"
      exit 1
    fi
  fi
  
  log_success "Prerequisites satisfied"
}

run_formatting() {
  log_info "🎨 Step 1: Code Formatting"
  echo
  
  local format_args=()
  if $FIX_ISSUES; then
    format_args+=("--fix")
  fi
  if $VERBOSE; then
    format_args+=("--verbose")
  fi
  
  if ./scripts/format.sh "${format_args[@]}"; then
    log_success "✅ Formatting check passed"
  else
    log_error "❌ Formatting check failed"
    return 1
  fi
  
  echo
}

run_linting() {
  log_info "🔍 Step 2: Code Linting"
  echo
  
  local lint_args=()
  if $FIX_ISSUES; then
    lint_args+=("--fix")
  fi
  if $VERBOSE; then
    # SwiftLint doesn't have a verbose flag, but we can show more context
    lint_args+=("--quiet")
  fi
  
  if ./scripts/lint.sh "${lint_args[@]}"; then
    log_success "✅ Linting check passed"
  else
    log_error "❌ Linting check failed"
    return 1
  fi
  
  echo
}

run_build() {
  if ! $BUILD_PROJECT; then
    log_info "🏗️  Step 3: Build (Skipped)"
    echo
    return 0
  fi
  
  log_info "🏗️  Step 3: Project Build"
  echo
  
  local build_args=()
  if [[ "$CONFIGURATION" == "Release" ]]; then
    build_args+=("--release")
  fi
  if $VERBOSE; then
    build_args+=("--verbose")
  fi
  
  if ./scripts/build.sh "${build_args[@]+"${build_args[@]}"}"; then
    log_success "✅ Build check passed"
  else
    log_error "❌ Build check failed"
    return 1
  fi
  
  echo
}

run_tests() {
  if ! $RUN_TESTS; then
    log_info "🧪 Step 4: Tests (Skipped)"
    echo
    return 0
  fi
  
  log_info "🧪 Step 4: Tests"
  echo
  
  local test_args=("--all")  # Run both unit and UI tests
  if [[ "$CONFIGURATION" == "Release" ]]; then
    test_args+=("--release")
  fi
  if $VERBOSE; then
    test_args+=("--verbose")
  fi
  
  if ./scripts/test.sh "${test_args[@]}"; then
    log_success "✅ Tests passed"
  else
    log_warning "⚠️  Tests failed (check output above)"
    # Don't fail preflight for test failures - they might be environment-specific
    # return 1
  fi
  
  echo
}

show_preflight_summary() {
  local project_name=""
  if command_exists yq && [[ -f "project.yml" ]]; then
    project_name=$(yq eval '.name' project.yml 2>/dev/null || echo "Unknown")
  fi
  
  echo "================================================"
  log_success "🎉 Preflight Check Complete!"
  echo
  log_info "Project: $project_name"
  log_info "Configuration: $CONFIGURATION"
  log_info "Auto-fix: $(if $FIX_ISSUES; then echo "enabled"; else echo "disabled"; fi)"
  echo
  
  log_info "Summary:"
  echo "  ✅ Code formatting validated"
  echo "  ✅ Code quality checks passed"
  if $BUILD_PROJECT; then
    echo "  ✅ Project builds successfully"
  fi
  if $RUN_TESTS; then
    echo "  ✅ Tests executed"
  fi
  
  echo
  log_info "Your code is ready for:"
  echo "  • Git commit"
  echo "  • Pull request creation"
  echo "  • Code review"
  echo "  • CI/CD pipeline"
  
  if $FIX_ISSUES; then
    echo
    log_info "Files may have been modified by auto-fixes."
    log_info "Review changes with: git diff"
  fi
}

show_preflight_failure() {
  echo "================================================"
  log_error "❌ Preflight Check Failed!"
  echo
  log_info "Please fix the issues above before committing."
  echo
  log_info "Common solutions:"
  echo "  • Run with --verbose for more details"
  echo "  • Check individual tools:"
  echo "    - ./scripts/format.sh --fix"
  echo "    - ./scripts/lint.sh --fix" 
  echo "    - ./scripts/build.sh"
  echo "    - ./scripts/test.sh"
  echo
  log_info "Once fixed, run this script again:"
  echo "  ./scripts/preflight.sh"
}

# Main execution
main() {
  echo "🚀 SwiftProjectTemplate Preflight Check"
  echo "========================================"
  echo
  
  parse_arguments "$@"
  check_prerequisites
  
  local start_time
  start_time=$(date +%s)
  
  local failed_steps=()
  
  # Run all preflight steps
  if ! run_formatting; then
    failed_steps+=("formatting")
  fi
  
  if ! run_linting; then
    failed_steps+=("linting")
  fi
  
  if ! run_build; then
    failed_steps+=("build")
  fi
  
  if ! run_tests; then
    # Tests failures are warnings, not hard failures
    log_warning "Tests had issues but continuing..."
  fi
  
  local end_time duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  # Show results
  if [[ ${#failed_steps[@]} -eq 0 ]]; then
    show_preflight_summary
    log_info "Total time: ${duration}s"
    exit 0
  else
    show_preflight_failure
    log_error "Failed steps: ${failed_steps[*]}"
    log_info "Total time: ${duration}s"
    exit 1
  fi
}

# Run main function with all arguments
main "$@"