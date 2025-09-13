#!/usr/bin/env bash
set -euo pipefail

# Test script for SwiftProjectTemplate projects
# Runs unit tests and UI tests with simulator configuration from simulator.yml

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
RUN_UNIT_TESTS=true
RUN_UI_TESTS=false
RUN_ALL_TESTS=false
CONFIGURATION="Debug"
ENABLE_COVERAGE=true
VERBOSE=false

show_help() {
  cat <<EOF
Test Script

Runs unit tests and/or UI tests for the iOS project using simulator configuration
from simulator.yml when available.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --ui                     Run UI tests only
  --unit                   Run unit tests only (default)
  --all                    Run both unit tests and UI tests
  --release                Run tests in Release configuration (default: Debug)
  --no-coverage            Disable code coverage collection
  --verbose                Show verbose test output
  --help                   Show this help message

EXAMPLES:
  $0                       # Run unit tests only
  $0 --ui                  # Run UI tests only
  $0 --all                 # Run both unit and UI tests
  $0 --all --release       # Run all tests in Release configuration
  $0 --verbose             # Run with verbose output

SIMULATOR CONFIGURATION:
  Tests use simulator configuration from simulator.yml if available:
  • Unit tests use 'simulators.tests' configuration
  • UI tests use 'simulators.ui-tests' configuration
  • Falls back to sensible defaults if simulator.yml not found

REQUIREMENTS:
  - Xcode and xcodebuild
  - Valid .xcodeproj file (run 'xcodegen' if needed)
  - iOS Simulator

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --ui)
        RUN_UNIT_TESTS=false
        RUN_UI_TESTS=true
        shift
        ;;
      --unit)
        RUN_UNIT_TESTS=true
        RUN_UI_TESTS=false
        shift
        ;;
      --all)
        RUN_ALL_TESTS=true
        RUN_UNIT_TESTS=true
        RUN_UI_TESTS=true
        shift
        ;;
      --release)
        CONFIGURATION="Release"
        shift
        ;;
      --no-coverage)
        ENABLE_COVERAGE=false
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

get_project_info() {
  if [[ -f "project.yml" ]]; then
    if command_exists yq; then
      PROJECT_NAME=$(yq eval '.name' project.yml)
      DEPLOYMENT_TARGET=$(yq eval '.options.deploymentTarget.iOS' project.yml)
    else
      log_error "yq is required to read project configuration"
      log_info "Install with: brew install yq"
      exit 1
    fi
  else
    log_error "project.yml not found"
    log_info "Run './scripts/setup.sh' first to configure the project"
    exit 1
  fi
  
  if [[ "$PROJECT_NAME" == "null" || -z "$PROJECT_NAME" ]]; then
    log_error "Could not determine project name from project.yml"
    exit 1
  fi
}

get_simulator_config() {
  local test_type="$1"  # "tests" or "ui-tests"
  local config_key="simulators.$test_type"
  
  if [[ -f "simulator.yml" && command_exists yq ]]; then
    local device os arch
    device=$(yq eval ".$config_key.device" simulator.yml 2>/dev/null || echo "")
    os=$(yq eval ".$config_key.os" simulator.yml 2>/dev/null || echo "")
    arch=$(yq eval ".$config_key.arch" simulator.yml 2>/dev/null || echo "")
    
    # Validate configuration
    if [[ -n "$device" && "$device" != "null" ]]; then
      echo "$device|$os|$arch"
      return
    fi
  fi
  
  # Fallback to default configuration
  local default_device="iPhone 15 Pro"
  local default_os="$DEPLOYMENT_TARGET"
  
  if [[ "$default_os" == "null" || -z "$default_os" ]]; then
    default_os="18.0"
  fi
  
  # Adjust device based on iOS version
  local major_version
  major_version=$(echo "$default_os" | cut -d'.' -f1)
  if [[ "$major_version" -lt "17" ]]; then
    default_device="iPhone 14 Pro"
  fi
  
  echo "$default_device|$default_os|arm64"
}

check_test_targets() {
  local has_unit_tests has_ui_tests
  
  if command_exists yq; then
    has_unit_tests=$(yq eval ".targets | has(\"${PROJECT_NAME}Tests\")" project.yml 2>/dev/null || echo "false")
    has_ui_tests=$(yq eval ".targets | has(\"${PROJECT_NAME}UITests\")" project.yml 2>/dev/null || echo "false")
  else
    # Fallback: check if directories exist
    has_unit_tests="false"
    has_ui_tests="false"
    
    if [[ -d "${PROJECT_NAME}Tests" ]]; then
      has_unit_tests="true"
    fi
    
    if [[ -d "${PROJECT_NAME}UITests" ]]; then
      has_ui_tests="true"
    fi
  fi
  
  if $RUN_UNIT_TESTS && [[ "$has_unit_tests" != "true" ]]; then
    log_warning "Unit test target '${PROJECT_NAME}Tests' not found"
    RUN_UNIT_TESTS=false
  fi
  
  if $RUN_UI_TESTS && [[ "$has_ui_tests" != "true" ]]; then
    log_warning "UI test target '${PROJECT_NAME}UITests' not found"
    RUN_UI_TESTS=false
  fi
  
  if [[ "$RUN_UNIT_TESTS" == "false" && "$RUN_UI_TESTS" == "false" ]]; then
    log_error "No test targets available to run"
    log_info "Create test targets in your project.yml configuration"
    exit 1
  fi
}

check_project_file() {
  local xcodeproj_path="${PROJECT_NAME}.xcodeproj"
  
  if [[ ! -d "$xcodeproj_path" ]]; then
    log_error "Xcode project not found: $xcodeproj_path"
    log_info "Generate it with: xcodegen"
    exit 1
  fi
}

run_unit_tests() {
  if ! $RUN_UNIT_TESTS; then
    return
  fi
  
  log_info "Running unit tests..."
  
  # Get simulator configuration for tests
  local sim_config device_name os_version
  sim_config=$(get_simulator_config "tests")
  device_name=$(echo "$sim_config" | cut -d'|' -f1)
  os_version=$(echo "$sim_config" | cut -d'|' -f2)
  
  log_info "Using simulator: $device_name (iOS $os_version)"
  
  local destination="platform=iOS Simulator,name=$device_name"
  
  # Prepare test arguments
  local test_args=(
    "test"
    "-project" "${PROJECT_NAME}.xcodeproj"
    "-scheme" "$PROJECT_NAME"
    "-destination" "$destination"
    "-configuration" "$CONFIGURATION"
    "-only-testing" "${PROJECT_NAME}Tests"
    "ONLY_ACTIVE_ARCH=YES"
    "CODE_SIGNING_REQUIRED=NO"
    "CODE_SIGNING_ALLOWED=NO"
  )
  
  # Add code coverage if enabled
  if $ENABLE_COVERAGE; then
    test_args+=("-enableCodeCoverage" "YES")
  fi
  
  # Execute tests
  local start_time
  start_time=$(date +%s)
  
  if $VERBOSE; then
    xcodebuild "${test_args[@]}"
  else
    if command_exists xcbeautify; then
      xcodebuild "${test_args[@]}" | xcbeautify
    else
      xcodebuild "${test_args[@]}"
    fi
  fi
  
  local end_time duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  log_success "Unit tests completed in ${duration}s"
}

run_ui_tests() {
  if ! $RUN_UI_TESTS; then
    return
  fi
  
  log_info "Running UI tests..."
  
  # Get simulator configuration for UI tests
  local sim_config device_name os_version
  sim_config=$(get_simulator_config "ui-tests")
  device_name=$(echo "$sim_config" | cut -d'|' -f1)
  os_version=$(echo "$sim_config" | cut -d'|' -f2)
  
  log_info "Using simulator: $device_name (iOS $os_version)"
  
  local destination="platform=iOS Simulator,name=$device_name"
  
  # Prepare test arguments
  local test_args=(
    "test"
    "-project" "${PROJECT_NAME}.xcodeproj"
    "-scheme" "$PROJECT_NAME"
    "-destination" "$destination"
    "-configuration" "$CONFIGURATION"
    "-only-testing" "${PROJECT_NAME}UITests"
    "ONLY_ACTIVE_ARCH=YES"
    "CODE_SIGNING_REQUIRED=NO"
    "CODE_SIGNING_ALLOWED=NO"
  )
  
  # UI tests typically don't need code coverage
  # but we'll include it if specifically requested
  if $ENABLE_COVERAGE; then
    test_args+=("-enableCodeCoverage" "YES")
  fi
  
  # Execute UI tests
  local start_time
  start_time=$(date +%s)
  
  log_warning "UI tests can take longer and may be flaky in some environments"
  
  if $VERBOSE; then
    xcodebuild "${test_args[@]}"
  else
    if command_exists xcbeautify; then
      xcodebuild "${test_args[@]}" | xcbeautify
    else
      xcodebuild "${test_args[@]}"
    fi
  fi
  
  local end_time duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  log_success "UI tests completed in ${duration}s"
}

show_coverage_info() {
  if ! $ENABLE_COVERAGE; then
    return
  fi
  
  log_info "Code coverage enabled"
  log_info "View coverage report in Xcode:"
  echo "  1. Open ${PROJECT_NAME}.xcodeproj"
  echo "  2. Go to Report Navigator (Cmd+9)"
  echo "  3. Select latest test run"
  echo "  4. Click Coverage tab"
}

display_test_summary() {
  echo
  log_success "🎉 Testing completed!"
  
  local tests_run=""
  if $RUN_UNIT_TESTS && $RUN_UI_TESTS; then
    tests_run="unit and UI tests"
  elif $RUN_UNIT_TESTS; then
    tests_run="unit tests"
  elif $RUN_UI_TESTS; then
    tests_run="UI tests"
  fi
  
  log_info "Results:"
  echo "  ✅ $tests_run passed"
  echo "  🔧 Configuration: $CONFIGURATION"
  
  if $ENABLE_COVERAGE; then
    echo "  📊 Code coverage collected"
  fi
  
  echo
  log_info "Next steps:"
  echo "  • Build: ./scripts/build.sh"
  echo "  • Lint: ./scripts/lint.sh"
  echo "  • Full check: ./scripts/preflight.sh"
}

# Main execution
main() {
  log_info "Project Test Runner"
  echo
  
  parse_arguments "$@"
  check_required_tools xcodebuild
  get_project_info
  check_project_file
  check_test_targets
  
  run_unit_tests
  run_ui_tests
  
  show_coverage_info
  display_test_summary
}

# Run main function with all arguments
main "$@"