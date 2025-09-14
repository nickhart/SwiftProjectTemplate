#!/usr/bin/env bash
set -euo pipefail

# XcodeGen configuration generator for SwiftProjectTemplate
# This script is called automatically by setup.sh after template generation
# It can also be run standalone to regenerate the Xcode project

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Configuration
FORCE_OVERWRITE=false
SKIP_PROJECT_GENERATION=false

show_help() {
  cat <<EOF
XcodeGen Configuration Script

This script manages XcodeGen project generation for SwiftProjectTemplate projects.
It ensures the Xcode project file stays in sync with the project.yml configuration.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --force                     Overwrite existing project.yml without prompting
  --skip-generation          Don't run 'xcodegen' after updating configuration
  --help                     Show this help message

EXAMPLES:
  $0                         # Standard project generation
  $0 --force                 # Overwrite existing project.yml
  $0 --skip-generation       # Only validate project.yml, don't generate .xcodeproj

WORKFLOW:
  1. Check if project.yml exists (exit if exists and --force not specified)
  2. Validate project.yml configuration using yq
  3. Run xcodegen to generate/update .xcodeproj file
  4. Validate the generated Xcode project

REQUIREMENTS:
  - yq (for YAML processing)
  - xcodegen (for project generation)
  - Valid project.yml file

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --force)
        FORCE_OVERWRITE=true
        shift
        ;;
      --skip-generation)
        SKIP_PROJECT_GENERATION=true
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

  # Check for required tools
  if ! check_required_tools yq xcodegen; then
    log_error "Missing required tools"
    log_info "Install missing tools with: brew bundle install"
    exit 1
  fi

  # Check for Xcode
  if ! check_xcode; then
    exit 1
  fi

  log_success "Prerequisites satisfied"
}

validate_project_yml() {
  local project_yml="$ROOT_DIR/project.yml"
  
  if [[ ! -f "$project_yml" ]]; then
    log_error "project.yml not found"
    log_info "Run './scripts/setup.sh' first to generate the project configuration"
    exit 1
  fi

  log_info "Validating project.yml..."

  # Check if it's valid YAML
  if ! yq eval '.' "$project_yml" >/dev/null 2>&1; then
    log_error "project.yml contains invalid YAML syntax"
    exit 1
  fi

  # Extract and validate key project settings
  local project_name
  project_name=$(yq eval '.name' "$project_yml")
  
  if [[ "$project_name" == "null" || -z "$project_name" ]]; then
    log_error "project.yml is missing required 'name' field"
    exit 1
  fi

  # Check for required targets
  local main_target_exists
  main_target_exists=$(yq eval ".targets | has(\"$project_name\")" "$project_yml")
  
  if [[ "$main_target_exists" != "true" ]]; then
    log_error "project.yml is missing main target '$project_name'"
    exit 1
  fi

  # Validate deployment target format
  local deployment_target
  deployment_target=$(yq eval '.options.deploymentTarget.iOS' "$project_yml")
  
  if [[ "$deployment_target" != "null" ]]; then
    if ! validate_ios_version "$deployment_target"; then
      log_warning "Invalid iOS deployment target format: $deployment_target"
    fi
  fi

  # Check for test targets
  local test_target="${project_name}Tests"
  local ui_test_target="${project_name}UITests"
  
  local has_test_target
  has_test_target=$(yq eval ".targets | has(\"$test_target\")" "$project_yml")
  
  local has_ui_test_target
  has_ui_test_target=$(yq eval ".targets | has(\"$ui_test_target\")" "$project_yml")
  
  if [[ "$has_test_target" != "true" ]]; then
    log_warning "Missing unit test target: $test_target"
  fi
  
  if [[ "$has_ui_test_target" != "true" ]]; then
    log_warning "Missing UI test target: $ui_test_target"
  fi

  log_success "project.yml validation passed"
  log_info "Project: $project_name"
  log_info "iOS Deployment Target: $deployment_target"
}

ensure_project_structure_exists() {
  log_info "Ensuring project structure exists..."

  # Get project name from project.yml
  local project_name
  project_name=$(yq eval '.name' "$ROOT_DIR/project.yml")

  # Define required directories based on project.yml targets
  local required_dirs=(
    "$project_name"
    "${project_name}Tests"
    "${project_name}UITests"
  )

  # Check each target's source directories
  local target_dirs=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && target_dirs+=("$line")
  done < <(yq eval '.targets[].sources[]' "$ROOT_DIR/project.yml" 2>/dev/null || true)

  for dir in "${target_dirs[@]}" "${required_dirs[@]}"; do
    if [[ -n "$dir" && "$dir" != "null" ]]; then
      if [[ ! -d "$dir" ]]; then
        log_info "Creating missing directory: $dir"
        mkdir -p "$dir"
      fi
    fi
  done

  # Ensure critical files exist
  local app_file="$project_name/${project_name}App.swift"
  if [[ ! -f "$app_file" ]]; then
    log_warning "Missing main app file: $app_file"
    log_info "This will be created during project generation"
  fi

  local info_plist="$project_name/Info.plist"
  if [[ ! -f "$info_plist" ]]; then
    log_warning "Missing Info.plist: $info_plist"
    log_info "This should be created during project generation"
  fi

  log_success "Project structure validated"
}

generate_xcode_project() {
  if $SKIP_PROJECT_GENERATION; then
    log_info "Skipping Xcode project generation (--skip-generation specified)"
    return
  fi

  log_info "Generating Xcode project with XcodeGen..."

  # Get project name for better error messages
  local project_name
  project_name=$(yq eval '.name' "$ROOT_DIR/project.yml" 2>/dev/null || echo "Unknown")

  # Run xcodegen with error handling
  if xcodegen generate --spec "$ROOT_DIR/project.yml"; then
    log_success "Xcode project generated successfully: ${project_name}.xcodeproj"
  else
    local exit_code=$?
    log_error "XcodeGen failed with exit code $exit_code"
    
    # Provide helpful troubleshooting info
    log_info "Troubleshooting steps:"
    log_info "1. Check project.yml syntax: yq eval '.' project.yml"
    log_info "2. Verify all source directories exist"
    log_info "3. Check XcodeGen docs: https://github.com/yonaskolb/XcodeGen"
    log_info "4. Run with verbose output: xcodegen generate --verbose"
    
    exit $exit_code
  fi
}

validate_generated_project() {
  if $SKIP_PROJECT_GENERATION; then
    return
  fi

  # Get project name
  local project_name
  project_name=$(yq eval '.name' "$ROOT_DIR/project.yml" 2>/dev/null || echo "Unknown")
  local xcodeproj_path="${project_name}.xcodeproj"

  if [[ ! -d "$xcodeproj_path" ]]; then
    log_error "Generated Xcode project not found: $xcodeproj_path"
    exit 1
  fi

  log_info "Validating generated Xcode project..."

  # Basic validation - check if project can be read by xcodebuild
  if xcodebuild -list -project "$xcodeproj_path" >/dev/null 2>&1; then
    log_success "Xcode project validation passed"
    
    # Show project info
    log_info "Project details:"
    xcodebuild -list -project "$xcodeproj_path" | head -20
  else
    log_error "Generated Xcode project appears to be corrupted"
    log_info "Try regenerating with: rm -rf '$xcodeproj_path' && xcodegen generate"
    exit 1
  fi
}

update_simulator_config() {
  local simulator_yml="$ROOT_DIR/simulator.yml"
  
  if [[ -f "$simulator_yml" ]]; then
    log_info "Checking simulator configuration..."
    
    # Get deployment target from project.yml
    local deployment_target
    deployment_target=$(yq eval '.options.deploymentTarget.iOS' "$ROOT_DIR/project.yml")
    
    if [[ "$deployment_target" != "null" && -n "$deployment_target" ]]; then
      # Update simulator.yml to match deployment target
      local current_os
      current_os=$(yq eval '.simulators.tests.os' "$simulator_yml" 2>/dev/null || echo "")
      
      if [[ "$current_os" != "$deployment_target" ]]; then
        log_info "Updating simulator configuration to match deployment target: $deployment_target"
        yq eval ".simulators.tests.os = \"$deployment_target\"" -i "$simulator_yml"
        yq eval ".simulators.ui-tests.os = \"$deployment_target\"" -i "$simulator_yml"
        log_success "Simulator configuration updated"
      fi
    fi
  else
    log_warning "simulator.yml not found - simulators may need manual configuration"
  fi
}

display_next_steps() {
  local project_name
  project_name=$(yq eval '.name' "$ROOT_DIR/project.yml" 2>/dev/null || echo "Unknown")

  echo
  log_success "🎉 XcodeGen configuration complete!"
  echo
  log_info "Generated files:"
  echo "  ✓ ${project_name}.xcodeproj - Xcode project file"
  echo "  ✓ Project structure validated"
  echo "  ✓ Simulator configuration updated"
  echo
  log_info "Next steps:"
  echo "  1. Open ${project_name}.xcodeproj in Xcode"
  echo "  2. Build and run your project (Cmd+R)"
  echo "  3. Run tests: ./scripts/test.sh"
  echo
  log_info "Project maintenance:"
  echo "  • After modifying project.yml: run 'xcodegen' or this script"
  echo "  • Adding/removing files: update project.yml and regenerate"
  echo "  • Simulator config: ./scripts/simulator.sh --config-tests <device>"
}

# Main execution
main() {
  log_info "XcodeGen Project Configuration"
  echo

  parse_arguments "$@"
  check_prerequisites
  validate_project_yml
  ensure_project_structure_exists
  generate_xcode_project
  validate_generated_project
  update_simulator_config
  
  display_next_steps
}

# Run main function with all arguments
main "$@"