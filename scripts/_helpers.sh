#!/usr/bin/env bash
# Shared helper functions for SwiftProjectTemplate scripts

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}INFO:${NC} $*"
}

log_success() {
  echo -e "${GREEN}SUCCESS:${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}WARNING:${NC} $*"
}

log_error() {
  echo -e "${RED}ERROR:${NC} $*" >&2
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if we're in a git repository
is_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Get project root directory
get_project_root() {
  if is_git_repo; then
    git rev-parse --show-toplevel
  else
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
}

# Check if file exists and is not empty
file_exists_and_not_empty() {
  [[ -f "$1" && -s "$1" ]]
}

# Validate project name (alphanumeric, no spaces, valid Swift identifier)
validate_project_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    return 1
  fi
  # Check if it starts with a letter and contains only alphanumeric characters
  if [[ ! "$name" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
    return 1
  fi
  return 0
}

# Validate iOS version format (e.g., 16.0, 17.5, 18.1)
validate_ios_version() {
  local version="$1"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    return 1
  fi
  return 0
}

# Validate Swift version format (e.g., 5.9, 5.10, 6.0)
validate_swift_version() {
  local version="$1"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    return 1
  fi
  return 0
}

# Validate bundle ID root format (e.g., com.yourname, com.company.team)
validate_bundle_id_root() {
  local bundle_id="$1"
  if [[ -z "$bundle_id" ]]; then
    return 1
  fi
  # Check if it follows reverse domain notation (at least one dot, alphanumeric + dots + hyphens)
  if [[ ! "$bundle_id" =~ ^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$ ]]; then
    return 1
  fi
  return 0
}

# Replace template variables in a file
# Usage: replace_template_vars "input_file" "output_file" "VAR1=value1" "VAR2=value2"
replace_template_vars() {
  local input_file="$1"
  local output_file="$2"
  shift 2
  
  local temp_file
  temp_file=$(mktemp)
  cp "$input_file" "$temp_file"
  
  for var_assignment in "$@"; do
    local var_name="${var_assignment%=*}"
    local var_value="${var_assignment#*=}"
    
    # Use a different delimiter for sed to avoid issues with forward slashes
    # Also escape any ampersands and backslashes in the replacement text
    var_value=$(echo "$var_value" | sed 's/\\/\\\\/g; s/&/\\&/g')
    
    # Use | as delimiter instead of / to avoid URL conflicts
    sed -i.bak "s|{{${var_name}}}|${var_value}|g" "$temp_file"
  done
  
  mv "$temp_file" "$output_file"
  rm -f "${temp_file}.bak"
}

# Check if Xcode is installed
check_xcode() {
  if ! command_exists xcodebuild; then
    log_error "Xcode is not installed or xcodebuild is not in PATH"
    log_info "Please install Xcode from the App Store"
    return 1
  fi
  return 0
}

# Get available simulators using xcrun simctl
get_available_simulators() {
  xcrun simctl list devices available --json 2>/dev/null || {
    log_error "Failed to get simulator list. Xcode Command Line Tools may not be installed."
    return 1
  }
}

# Check if required tools are installed
check_required_tools() {
  local missing_tools=()
  
  for tool in "$@"; do
    if ! command_exists "$tool"; then
      missing_tools+=("$tool")
    fi
  done
  
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    log_info "Run 'brew bundle install' to install missing dependencies"
    return 1
  fi
  
  return 0
}