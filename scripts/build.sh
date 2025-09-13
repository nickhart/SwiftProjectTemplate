#!/usr/bin/env bash
set -euo pipefail

# Build script for SwiftProjectTemplate projects
# Supports building for simulator and device with various configurations

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
BUILD_FOR_DEVICE=false
CONFIGURATION="Debug"
CLEAN_BUILD=false
VERBOSE=false

show_help() {
  cat <<EOF
Build Script

Builds the iOS project for simulator or device with various configuration options.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --device                 Build for device (default: simulator)
  --release                Build in Release configuration (default: Debug)
  --clean                  Clean build folder before building
  --verbose                Show verbose build output
  --help                   Show this help message

EXAMPLES:
  $0                       # Build for simulator in Debug
  $0 --device              # Build for device in Debug
  $0 --release             # Build for simulator in Release
  $0 --device --release    # Build for device in Release
  $0 --clean --verbose     # Clean build with verbose output

REQUIREMENTS:
  - Xcode and xcodebuild
  - Valid .xcodeproj file (run 'xcodegen' if needed)
  - For device builds: valid development team and certificates

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --device)
        BUILD_FOR_DEVICE=true
        shift
        ;;
      --release)
        CONFIGURATION="Release"
        shift
        ;;
      --clean)
        CLEAN_BUILD=true
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

determine_destination() {
  if $BUILD_FOR_DEVICE; then
    echo "generic/platform=iOS"
  else
    # Choose simulator based on deployment target
    local simulator_name="iPhone 15 Pro"
    
    if [[ "$DEPLOYMENT_TARGET" != "null" && -n "$DEPLOYMENT_TARGET" ]]; then
      local major_version
      major_version=$(echo "$DEPLOYMENT_TARGET" | cut -d'.' -f1)
      
      if [[ "$major_version" -lt "17" ]]; then
        simulator_name="iPhone 14 Pro"
      fi
    fi
    
    echo "platform=iOS Simulator,name=$simulator_name"
  fi
}

check_project_file() {
  local xcodeproj_path="${PROJECT_NAME}.xcodeproj"
  
  if [[ ! -d "$xcodeproj_path" ]]; then
    log_error "Xcode project not found: $xcodeproj_path"
    log_info "Generate it with: xcodegen"
    exit 1
  fi
  
  # Validate project can be read
  if ! xcodebuild -list -project "$xcodeproj_path" >/dev/null 2>&1; then
    log_error "Xcode project appears to be corrupted: $xcodeproj_path"
    log_info "Regenerate it with: rm -rf '$xcodeproj_path' && xcodegen"
    exit 1
  fi
}

perform_clean_build() {
  if $CLEAN_BUILD; then
    log_info "Cleaning build folder..."
    
    xcodebuild clean \
      -project "${PROJECT_NAME}.xcodeproj" \
      -scheme "$PROJECT_NAME" \
      -configuration "$CONFIGURATION"
      
    log_success "Clean completed"
  fi
}

build_project() {
  local destination
  destination=$(determine_destination)
  
  local build_type
  if $BUILD_FOR_DEVICE; then
    build_type="device"
  else
    build_type="simulator"
  fi
  
  log_info "Building $PROJECT_NAME for $build_type ($CONFIGURATION configuration)..."
  log_info "Destination: $destination"
  
  # Prepare build arguments
  local build_args=(
    "build"
    "-project" "${PROJECT_NAME}.xcodeproj"
    "-scheme" "$PROJECT_NAME"
    "-destination" "$destination"
    "-configuration" "$CONFIGURATION"
  )
  
  # Add device-specific settings
  if $BUILD_FOR_DEVICE; then
    build_args+=(
      "CODE_SIGNING_REQUIRED=YES"
      "CODE_SIGNING_ALLOWED=YES"
    )
  else
    build_args+=(
      "ONLY_ACTIVE_ARCH=YES"
      "CODE_SIGNING_REQUIRED=NO"
      "CODE_SIGNING_ALLOWED=NO"
    )
  fi
  
  # Add verbose output if requested
  local output_filter=""
  if $VERBOSE; then
    log_info "Running with verbose output..."
  else
    # Use xcbeautify if available for prettier output
    if command_exists xcbeautify; then
      output_filter="| xcbeautify"
    fi
  fi
  
  # Execute build
  local start_time
  start_time=$(date +%s)
  
  if $VERBOSE; then
    xcodebuild "${build_args[@]}"
  else
    if command_exists xcbeautify; then
      xcodebuild "${build_args[@]}" | xcbeautify
    else
      xcodebuild "${build_args[@]}"
    fi
  fi
  
  local end_time duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  log_success "Build completed successfully in ${duration}s"
}

show_build_artifacts() {
  log_info "Build artifacts:"
  
  # Find build products
  local build_dir="build/$CONFIGURATION"
  if $BUILD_FOR_DEVICE; then
    build_dir="${build_dir}-iphoneos"
  else
    build_dir="${build_dir}-iphonesimulator"
  fi
  
  if [[ -d "$build_dir" ]]; then
    local app_path="${build_dir}/${PROJECT_NAME}.app"
    if [[ -d "$app_path" ]]; then
      echo "  📱 App: $app_path"
      
      # Show app size
      local app_size
      app_size=$(du -sh "$app_path" 2>/dev/null | cut -f1 || echo "unknown")
      echo "  📦 Size: $app_size"
    fi
  else
    log_info "Build artifacts location not found (may be in DerivedData)"
  fi
}

display_next_steps() {
  echo
  log_success "🎉 Build completed!"
  
  if $BUILD_FOR_DEVICE; then
    log_info "Device build ready for:"
    echo "  • Archive and distribute"
    echo "  • Install on connected device"
    echo "  • TestFlight upload"
  else
    log_info "Simulator build ready for:"
    echo "  • Run in Xcode (Cmd+R)"
    echo "  • Install on simulator"
    echo "  • Testing with './scripts/test.sh'"
  fi
  
  echo
  log_info "Next steps:"
  echo "  • Test: ./scripts/test.sh"
  echo "  • Lint: ./scripts/lint.sh"
  echo "  • Full check: ./scripts/preflight.sh"
}

# Main execution
main() {
  log_info "Project Build Script"
  echo
  
  parse_arguments "$@"
  check_required_tools xcodebuild
  get_project_info
  check_project_file
  perform_clean_build
  build_project
  show_build_artifacts
  display_next_steps
}

# Run main function with all arguments
main "$@"