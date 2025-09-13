#!/usr/bin/env bash
set -euo pipefail

# Enhanced simulator management script for SwiftProjectTemplate
# Extends basic simulator management with intelligent configuration using yq

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

show_help() {
  cat <<EOF
Enhanced Simulator Management Script

This script provides comprehensive iOS simulator management with intelligent
configuration that integrates with your project's deployment target and
simulator.yml configuration file.

USAGE:
  $0 <COMMAND> [OPTIONS]

COMMANDS:
  list [OPTIONS]                           List available simulators
  create [OPTIONS]                         Create a new simulator
  boot <udid_or_name>                      Boot a simulator
  shutdown <udid_or_name>                  Shutdown a simulator
  erase <udid_or_name>                     Erase simulator data
  delete <udid_or_name>                    Delete a simulator
  install <udid_or_name> <app_path>        Install app to simulator
  config-tests <device_name>               ✨ Configure simulator.yml for tests
  config-ui-tests <device_name>            ✨ Configure simulator.yml for UI tests
  show-config                              Show current simulator.yml configuration
  optimal-os [device_name]                 Show optimal OS version for device

LIST OPTIONS:
  --family <iPhone|iPad|Apple Watch>      Filter by device family
  --device <device_name>                  Filter by specific device name
  --os <version>                          Filter by OS version (e.g., 18.1, 17.5)
  --available-only                        Show only booted/shutdown devices
  --json                                  Output raw JSON

CREATE OPTIONS:
  --device <device_name>                  Device type (required)
  --os <version>                          OS version (required)
  --name <simulator_name>                 Custom name for simulator (required)

CONFIG OPTIONS (for config-tests/config-ui-tests):
  --os <version>                          Override auto-detected OS version
  --arch <arm64|x86_64>                   Override auto-detected architecture
  --force                                 Update config without prompting

EXAMPLES:
  # Basic simulator management
  $0 list --family iPhone --os 18.1
  $0 create --device "iPhone 15 Pro" --os 18.1 --name "Test Device"
  $0 boot "iPhone 15 Pro"

  # ✨ Enhanced configuration features
  $0 config-tests "iPhone 16 Pro Max"        # Auto-configure for tests
  $0 config-ui-tests "iPad Air 11-inch"      # Auto-configure for UI tests
  $0 optimal-os "iPhone 15 Pro"              # Show optimal OS for device
  $0 show-config                             # Show current configuration

  # Advanced configuration
  $0 config-tests "iPhone 15 Pro" --os 17.0 --force
  $0 config-ui-tests "iPad Pro" --arch x86_64

INTELLIGENT FEATURES:
  • Auto-detects optimal iOS version based on project's deployment target
  • Auto-detects Mac architecture (ARM64 vs Intel) for simulator selection
  • Updates simulator.yml configuration using yq
  • Validates device names against available simulator types
  • Preserves existing configuration when possible

EOF
}

# Get deployment target from project.yml if available
get_project_deployment_target() {
  local project_yml="$ROOT_DIR/project.yml"
  if [[ -f "$project_yml" ]] && command_exists yq; then
    yq eval '.options.deploymentTarget.iOS' "$project_yml" 2>/dev/null | grep -v "null" || echo ""
  else
    echo ""
  fi
}

# Detect optimal OS version for a device
get_optimal_os_version() {
  local device_name="$1"
  local deployment_target
  deployment_target=$(get_project_deployment_target)
  
  if [[ -n "$deployment_target" ]]; then
    echo "$deployment_target"
    return
  fi
  
  # Fallback: get latest available iOS version for the device
  local latest_ios
  latest_ios=$(xcrun simctl list runtimes --json 2>/dev/null | \
    jq -r '.runtimes[] | select(.name | startswith("iOS")) | .version' | \
    sort -V | tail -1 2>/dev/null || echo "18.1")
  
  echo "$latest_ios"
}

# Detect Mac architecture for simulator
detect_mac_architecture() {
  case "$(uname -m)" in
    arm64) echo "arm64" ;;
    x86_64) echo "x86_64" ;;
    *) echo "arm64" ;; # Default to Apple Silicon
  esac
}

# Validate device name exists in available device types
validate_device_name() {
  local device_name="$1"
  local available_devices
  
  available_devices=$(xcrun simctl list devicetypes --json 2>/dev/null | \
    jq -r '.devicetypes[].name' 2>/dev/null || echo "")
  
  if [[ -z "$available_devices" ]]; then
    log_warning "Could not fetch available device types"
    return 0  # Allow it to proceed, xcodegen will catch the error
  fi
  
  if echo "$available_devices" | grep -Fxq "$device_name"; then
    return 0
  else
    return 1
  fi
}

# Show available device types for family
show_device_suggestions() {
  local family="$1"
  local devices
  
  log_info "Available $family devices:"
  devices=$(xcrun simctl list devicetypes --json 2>/dev/null | \
    jq -r ".devicetypes[] | select(.productFamily == \"$family\") | .name" 2>/dev/null | \
    head -10 || echo "")
  
  if [[ -n "$devices" ]]; then
    echo "$devices" | sed 's/^/  • /'
  else
    log_warning "Could not fetch device suggestions"
  fi
}

# Update simulator.yml configuration
update_simulator_config() {
  local config_type="$1"  # "tests" or "ui-tests"
  local device_name="$2"
  local os_version="$3"
  local architecture="$4"
  local force_update="$5"
  
  local simulator_yml="$ROOT_DIR/simulator.yml"
  
  # Create simulator.yml if it doesn't exist
  if [[ ! -f "$simulator_yml" ]]; then
    log_info "Creating simulator.yml configuration file..."
    cat > "$simulator_yml" <<EOF
# Simulator configuration
# This file is managed by scripts/simulator.sh
simulators:
  tests:
    device: "iPhone 15 Pro"
    os: "18.0"
    arch: "arm64"
  ui-tests:
    device: "iPhone 15 Pro"
    os: "18.0"
    arch: "arm64"
EOF
  fi
  
  # Check if yq is available
  if ! command_exists yq; then
    log_error "yq is required for configuration management"
    log_info "Install with: brew install yq"
    exit 1
  fi
  
  # Validate current config exists
  if ! yq eval ".simulators.$config_type" "$simulator_yml" >/dev/null 2>&1; then
    log_error "Invalid simulator.yml structure"
    log_info "Expected structure: simulators.${config_type}.device, .os, .arch"
    exit 1
  fi
  
  # Get current configuration
  local current_device current_os current_arch
  current_device=$(yq eval ".simulators.$config_type.device" "$simulator_yml" 2>/dev/null || echo "")
  current_os=$(yq eval ".simulators.$config_type.os" "$simulator_yml" 2>/dev/null || echo "")
  current_arch=$(yq eval ".simulators.$config_type.arch" "$simulator_yml" 2>/dev/null || echo "")
  
  # Check if update is needed
  if [[ "$current_device" == "$device_name" && "$current_os" == "$os_version" && "$current_arch" == "$architecture" ]]; then
    log_success "Configuration already up to date for $config_type"
    return
  fi
  
  # Prompt for confirmation unless force is specified
  if [[ "$force_update" != "true" ]]; then
    echo
    log_info "Current $config_type configuration:"
    echo "  Device: $current_device"
    echo "  OS: $current_os"
    echo "  Architecture: $current_arch"
    echo
    log_info "New $config_type configuration:"
    echo "  Device: $device_name"
    echo "  OS: $os_version"
    echo "  Architecture: $architecture"
    echo
    
    while true; do
      read -p "Update $config_type configuration? (y/N): " yn
      case $yn in
        [Yy]* ) break;;
        [Nn]* | "" ) 
          log_info "Configuration update cancelled"
          return;;
        * ) echo "Please answer yes or no.";;
      esac
    done
  fi
  
  # Update configuration
  log_info "Updating $config_type configuration..."
  yq eval ".simulators.$config_type.device = \"$device_name\"" -i "$simulator_yml"
  yq eval ".simulators.$config_type.os = \"$os_version\"" -i "$simulator_yml"
  yq eval ".simulators.$config_type.arch = \"$architecture\"" -i "$simulator_yml"
  
  log_success "Updated $config_type configuration in simulator.yml"
}

# Show current simulator configuration
show_current_config() {
  local simulator_yml="$ROOT_DIR/simulator.yml"
  
  if [[ ! -f "$simulator_yml" ]]; then
    log_warning "simulator.yml not found"
    log_info "Run './scripts/simulator.sh config-tests <device>' to create configuration"
    return
  fi
  
  if ! command_exists yq; then
    log_error "yq is required to read configuration"
    log_info "Install with: brew install yq"
    exit 1
  fi
  
  echo "Current Simulator Configuration:"
  echo "================================"
  
  # Check if configuration exists
  if ! yq eval '.simulators' "$simulator_yml" >/dev/null 2>&1; then
    log_error "Invalid simulator.yml format"
    return
  fi
  
  # Show tests configuration
  local tests_device tests_os tests_arch
  tests_device=$(yq eval '.simulators.tests.device' "$simulator_yml" 2>/dev/null || echo "not configured")
  tests_os=$(yq eval '.simulators.tests.os' "$simulator_yml" 2>/dev/null || echo "not configured")
  tests_arch=$(yq eval '.simulators.tests.arch' "$simulator_yml" 2>/dev/null || echo "not configured")
  
  echo "Tests:"
  echo "  Device: $tests_device"
  echo "  OS: $tests_os"
  echo "  Architecture: $tests_arch"
  
  # Show UI tests configuration
  local ui_tests_device ui_tests_os ui_tests_arch
  ui_tests_device=$(yq eval '.simulators.ui-tests.device' "$simulator_yml" 2>/dev/null || echo "not configured")
  ui_tests_os=$(yq eval '.simulators.ui-tests.os' "$simulator_yml" 2>/dev/null || echo "not configured")
  ui_tests_arch=$(yq eval '.simulators.ui-tests.arch' "$simulator_yml" 2>/dev/null || echo "not configured")
  
  echo
  echo "UI Tests:"
  echo "  Device: $ui_tests_device"
  echo "  OS: $ui_tests_os"
  echo "  Architecture: $ui_tests_arch"
  
  # Show project deployment target if available
  local deployment_target
  deployment_target=$(get_project_deployment_target)
  if [[ -n "$deployment_target" ]]; then
    echo
    echo "Project Deployment Target: iOS $deployment_target"
  fi
}

# Configure simulators for tests
config_tests() {
  local device_name="$1"
  local os_override="${2:-}"
  local arch_override="${3:-}"
  local force_update="${4:-false}"
  
  log_info "Configuring simulator for unit tests..."
  
  # Validate device name
  if ! validate_device_name "$device_name"; then
    log_error "Device '$device_name' not found in available device types"
    
    # Determine device family for suggestions
    local family=""
    if [[ "$device_name" == *"iPhone"* ]]; then
      family="iPhone"
    elif [[ "$device_name" == *"iPad"* ]]; then
      family="iPad"
    else
      # Try to guess or show all
      log_info "Available devices:"
      xcrun simctl list devicetypes --json 2>/dev/null | \
        jq -r '.devicetypes[].name' 2>/dev/null | head -20 | sed 's/^/  • /' || \
        log_warning "Could not fetch device list"
      exit 1
    fi
    
    show_device_suggestions "$family"
    exit 1
  fi
  
  # Determine OS version
  local os_version
  if [[ -n "$os_override" ]]; then
    os_version="$os_override"
  else
    os_version=$(get_optimal_os_version "$device_name")
  fi
  
  # Determine architecture
  local architecture
  if [[ -n "$arch_override" ]]; then
    architecture="$arch_override"
  else
    architecture=$(detect_mac_architecture)
  fi
  
  log_info "Configuration details:"
  echo "  Device: $device_name"
  echo "  OS: iOS $os_version"
  echo "  Architecture: $architecture"
  echo
  
  update_simulator_config "tests" "$device_name" "$os_version" "$architecture" "$force_update"
}

# Configure simulators for UI tests  
config_ui_tests() {
  local device_name="$1"
  local os_override="${2:-}"
  local arch_override="${3:-}"
  local force_update="${4:-false}"
  
  log_info "Configuring simulator for UI tests..."
  
  # Validate device name
  if ! validate_device_name "$device_name"; then
    log_error "Device '$device_name' not found in available device types"
    
    # Show suggestions
    local family=""
    if [[ "$device_name" == *"iPhone"* ]]; then
      family="iPhone"
    elif [[ "$device_name" == *"iPad"* ]]; then
      family="iPad"
    else
      log_info "Available devices:"
      xcrun simctl list devicetypes --json 2>/dev/null | \
        jq -r '.devicetypes[].name' 2>/dev/null | head -20 | sed 's/^/  • /' || \
        log_warning "Could not fetch device list"
      exit 1
    fi
    
    show_device_suggestions "$family"
    exit 1
  fi
  
  # Determine OS version
  local os_version
  if [[ -n "$os_override" ]]; then
    os_version="$os_override"
  else
    os_version=$(get_optimal_os_version "$device_name")
  fi
  
  # Determine architecture
  local architecture
  if [[ -n "$arch_override" ]]; then
    architecture="$arch_override"
  else
    architecture=$(detect_mac_architecture)
  fi
  
  log_info "Configuration details:"
  echo "  Device: $device_name"
  echo "  OS: iOS $os_version"
  echo "  Architecture: $architecture"
  echo
  
  update_simulator_config "ui-tests" "$device_name" "$os_version" "$architecture" "$force_update"
}

# Show optimal OS version for a device
show_optimal_os() {
  local device_name="${1:-}"
  
  if [[ -z "$device_name" ]]; then
    # Show optimal OS for project
    local deployment_target
    deployment_target=$(get_project_deployment_target)
    if [[ -n "$deployment_target" ]]; then
      echo "Optimal OS version (based on project deployment target): iOS $deployment_target"
    else
      echo "No project deployment target found. Latest available iOS will be used."
      local latest_ios
      latest_ios=$(xcrun simctl list runtimes --json 2>/dev/null | \
        jq -r '.runtimes[] | select(.name | startswith("iOS")) | .version' | \
        sort -V | tail -1 2>/dev/null || echo "18.1")
      echo "Latest available iOS: $latest_ios"
    fi
  else
    # Show optimal OS for specific device
    local optimal_os
    optimal_os=$(get_optimal_os_version "$device_name")
    echo "Optimal OS version for $device_name: iOS $optimal_os"
  fi
}

# Parse device types and runtimes from simctl list
get_device_types() {
  xcrun simctl list devicetypes --json | jq -r '.devicetypes[] | select(.productFamily == "'"$1"'") | .name'
}

get_runtimes() {
  xcrun simctl list runtimes --json | jq -r '.runtimes[] | select(.name | startswith("iOS")) | .version'
}

list_simulators() {
  local family_filter=""
  local device_filter=""
  local os_filter=""
  local available_only=false
  local json_output=false

  # Parse list options
  while [[ $# -gt 0 ]]; do
    case $1 in
      --family)
        family_filter="$2"
        shift 2
        ;;
      --device)
        device_filter="$2"
        shift 2
        ;;
      --os)
        os_filter="$2"
        shift 2
        ;;
      --available-only)
        available_only=true
        shift
        ;;
      --json)
        json_output=true
        shift
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done

  if $json_output; then
    xcrun simctl list devices --json
    return
  fi

  local jq_filter='.devices | to_entries[] | .key as $runtime | .value[] | select(.isAvailable == true'

  if [[ -n "$family_filter" ]]; then
    jq_filter="$jq_filter and (.deviceTypeIdentifier | contains(\"$family_filter\"))"
  fi

  if [[ -n "$device_filter" ]]; then
    jq_filter="$jq_filter and (.name | contains(\"$device_filter\"))"
  fi

  if [[ -n "$os_filter" ]]; then
    jq_filter="$jq_filter and (\$runtime | contains(\"$os_filter\"))"
  fi

  if $available_only; then
    jq_filter="$jq_filter and (.state == \"Booted\" or .state == \"Shutdown\")"
  fi

  jq_filter="$jq_filter) | \"\(.name) (\(.udid)) [\(.state)] - \" + \$runtime"

  echo "Available Simulators:"
  echo "===================="
  xcrun simctl list devices --json | jq -r "$jq_filter" | sort
}

create_simulator() {
  local device_type=""
  local os_version=""
  local sim_name=""

  # Parse create options
  while [[ $# -gt 0 ]]; do
    case $1 in
      --device)
        device_type="$2"
        shift 2
        ;;
      --os)
        os_version="$2"
        shift 2
        ;;
      --name)
        sim_name="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$device_type" || -z "$os_version" || -z "$sim_name" ]]; then
    echo "Error: --device, --os, and --name are required for create command" >&2
    echo "Example: $0 create --device \"iPhone 15 Pro\" --os 18.1 --name \"My Test Device\""
    exit 1
  fi

  # Find matching device type identifier
  local device_id
  device_id=$(xcrun simctl list devicetypes --json | jq -r ".devicetypes[] | select(.name == \"$device_type\") | .identifier")

  if [[ -z "$device_id" ]]; then
    echo "Error: Device type '$device_type' not found" >&2
    echo "Available device types:"
    xcrun simctl list devicetypes --json | jq -r '.devicetypes[].name' | sort
    exit 1
  fi

  # Find matching runtime identifier
  local runtime_id
  runtime_id=$(xcrun simctl list runtimes --json | jq -r ".runtimes[] | select(.version == \"$os_version\" and .name | startswith(\"iOS\")) | .identifier")

  if [[ -z "$runtime_id" ]]; then
    echo "Error: iOS runtime version '$os_version' not found" >&2
    echo "Available iOS runtimes:"
    xcrun simctl list runtimes --json | jq -r '.runtimes[] | select(.name | startswith("iOS")) | .version' | sort
    exit 1
  fi

  echo "Creating simulator '$sim_name' with $device_type running iOS $os_version..."
  local udid
  udid=$(xcrun simctl create "$sim_name" "$device_id" "$runtime_id")
  echo "Created simulator with UDID: $udid"
}

find_simulator() {
  local identifier="$1"

  # First try to find by UDID
  if xcrun simctl list devices --json | jq -e ".devices[][] | select(.udid == \"$identifier\")" >/dev/null; then
    echo "$identifier"
    return
  fi

  # Then try to find by name
  local udid
  udid=$(xcrun simctl list devices --json | jq -r ".devices[][] | select(.name == \"$identifier\") | .udid" | head -n1)

  if [[ -n "$udid" ]]; then
    echo "$udid"
    return
  fi

  echo "Error: Simulator '$identifier' not found" >&2
  exit 1
}

boot_simulator() {
  local identifier="$1"
  local udid
  udid=$(find_simulator "$identifier")

  echo "Booting simulator $identifier ($udid)..."
  xcrun simctl boot "$udid"
  echo "Simulator booted successfully"
}

shutdown_simulator() {
  local identifier="$1"
  local udid
  udid=$(find_simulator "$identifier")

  echo "Shutting down simulator $identifier ($udid)..."
  xcrun simctl shutdown "$udid"
  echo "Simulator shut down successfully"
}

erase_simulator() {
  local identifier="$1"
  local udid
  udid=$(find_simulator "$identifier")

  echo "Erasing simulator $identifier ($udid)..."
  xcrun simctl erase "$udid"
  echo "Simulator erased successfully"
}

delete_simulator() {
  local identifier="$1"
  local udid
  udid=$(find_simulator "$identifier")

  echo "Deleting simulator $identifier ($udid)..."
  xcrun simctl delete "$udid"
  echo "Simulator deleted successfully"
}

install_app() {
  local identifier="$1"
  local app_path="$2"
  local udid
  udid=$(find_simulator "$identifier")

  if [[ ! -e "$app_path" ]]; then
    echo "Error: App path '$app_path' does not exist" >&2
    exit 1
  fi

  echo "Installing app at $app_path to simulator $identifier ($udid)..."
  xcrun simctl install "$udid" "$app_path"
  echo "App installed successfully"
}

# Main command parsing
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

case "$1" in
  list)
    shift
    list_simulators "$@"
    ;;
  create)
    shift
    create_simulator "$@"
    ;;
  boot)
    if [[ $# -ne 2 ]]; then
      echo "Usage: $0 boot <udid_or_name>" >&2
      exit 1
    fi
    boot_simulator "$2"
    ;;
  shutdown)
    if [[ $# -ne 2 ]]; then
      echo "Usage: $0 shutdown <udid_or_name>" >&2
      exit 1
    fi
    shutdown_simulator "$2"
    ;;
  erase)
    if [[ $# -ne 2 ]]; then
      echo "Usage: $0 erase <udid_or_name>" >&2
      exit 1
    fi
    erase_simulator "$2"
    ;;
  delete)
    if [[ $# -ne 2 ]]; then
      echo "Usage: $0 delete <udid_or_name>" >&2
      exit 1
    fi
    delete_simulator "$2"
    ;;
  install)
    if [[ $# -ne 3 ]]; then
      echo "Usage: $0 install <udid_or_name> <app_path>" >&2
      exit 1
    fi
    install_app "$2" "$3"
    ;;
  config-tests)
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 config-tests <device_name> [--os <version>] [--arch <arch>] [--force]" >&2
      exit 1
    fi
    
    device_name="$2"
    shift 2
    
    os_override=""
    arch_override=""
    force_update="false"
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --os)
          os_override="$2"
          shift 2
          ;;
        --arch)
          arch_override="$2"
          shift 2
          ;;
        --force)
          force_update="true"
          shift
          ;;
        *)
          echo "Unknown option: $1" >&2
          exit 1
          ;;
      esac
    done
    
    config_tests "$device_name" "$os_override" "$arch_override" "$force_update"
    ;;
  config-ui-tests)
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 config-ui-tests <device_name> [--os <version>] [--arch <arch>] [--force]" >&2
      exit 1
    fi
    
    device_name="$2"
    shift 2
    
    os_override=""
    arch_override=""
    force_update="false"
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --os)
          os_override="$2"
          shift 2
          ;;
        --arch)
          arch_override="$2"
          shift 2
          ;;
        --force)
          force_update="true"
          shift
          ;;
        *)
          echo "Unknown option: $1" >&2
          exit 1
          ;;
      esac
    done
    
    config_ui_tests "$device_name" "$os_override" "$arch_override" "$force_update"
    ;;
  show-config)
    show_current_config
    ;;
  optimal-os)
    show_optimal_os "${2:-}"
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Use '$0 help' for usage information" >&2
    exit 1
    ;;
esac