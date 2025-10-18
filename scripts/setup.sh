#!/usr/bin/env bash
set -euo pipefail

# Simplified setup script for SwiftProjectTemplate
# Does in-place replacement of placeholders instead of template processing

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
PROJECT_NAME=""
DEPLOYMENT_TARGET="18.0"
SWIFT_VERSION="6.2"
PROJECT_TYPE="private"
BUNDLE_ID_ROOT="com.yourcompany"
TEST_FRAMEWORK="swift-testing"
SOURCE_LANGUAGE="en"
USE_GIT_HOOKS=true
CREATE_INITIAL_COMMIT=true
FORCE_OVERWRITE=false
SKIP_BREW=false

show_help() {
  cat <<EOF
SwiftProjectTemplate Setup Script

This script configures the template by replacing placeholders with your project details.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --project-name <name>         Project name (required)
  --bundle-id-root <root>       Bundle identifier root (default: $BUNDLE_ID_ROOT)
  --deployment-target <version> iOS deployment target (default: $DEPLOYMENT_TARGET)
  --swift-version <version>     Swift version (default: $SWIFT_VERSION)
  --test-framework <framework>  Test framework: swift-testing or xctest (default: $TEST_FRAMEWORK)
  --source-language <code>      Source language (default: $SOURCE_LANGUAGE)
  --git-hooks                   Enable git pre-commit hooks (default)
  --no-git-hooks                Disable git pre-commit hooks
  --commit                      Create initial git commit (default)
  --no-commit                   Skip initial git commit
  --public                      Make this a public project
  --private                     Make this a private project (default)
  --force                       Overwrite existing files without prompting
  --skip-brew                   Skip Homebrew dependency installation
  --help                        Show this help message

EXAMPLES:
  $0 --project-name "MyApp"
  $0 --project-name "MyApp" --public --deployment-target 17.0

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project-name)
        PROJECT_NAME="$2"
        shift 2
        ;;
      --bundle-id-root)
        BUNDLE_ID_ROOT="$2"
        shift 2
        ;;
      --deployment-target)
        DEPLOYMENT_TARGET="$2"
        shift 2
        ;;
      --swift-version)
        SWIFT_VERSION="$2"
        shift 2
        ;;
      --test-framework)
        TEST_FRAMEWORK="$2"
        shift 2
        ;;
      --source-language)
        SOURCE_LANGUAGE="$2"
        shift 2
        ;;
      --git-hooks)
        USE_GIT_HOOKS=true
        shift
        ;;
      --no-git-hooks)
        USE_GIT_HOOKS=false
        shift
        ;;
      --commit)
        CREATE_INITIAL_COMMIT=true
        shift
        ;;
      --no-commit)
        CREATE_INITIAL_COMMIT=false
        shift
        ;;
      --public)
        PROJECT_TYPE="public"
        shift
        ;;
      --private)
        PROJECT_TYPE="private"
        shift
        ;;
      --force)
        FORCE_OVERWRITE=true
        shift
        ;;
      --skip-brew)
        SKIP_BREW=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
    esac
  done
}

validate_project_name() {
  if [[ -z "$PROJECT_NAME" ]]; then
    log_error "Project name is required"
    echo "Use: $0 --project-name YourProjectName"
    exit 1
  fi

  # Validate it's a valid Swift identifier
  if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
    log_error "Invalid project name. Must start with a letter and contain only alphanumerics."
    exit 1
  fi
}

install_dependencies() {
  if $SKIP_BREW; then
    log_info "Skipping Homebrew dependency installation"
    return
  fi

  log_info "Installing Homebrew dependencies..."

  if ! command_exists brew; then
    log_error "Homebrew is not installed. Install from https://brew.sh"
    exit 1
  fi

  brew bundle install --file="$ROOT_DIR/Brewfile"
  log_success "Dependencies installed"
}

replace_placeholders() {
  log_info "Replacing placeholders in project files..."

  local project_name_lower
  project_name_lower=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')

  # Prepare replacement values
  local license_badge=""
  local license_section=""
  local contributing_section=""

  if [[ "$PROJECT_TYPE" == "public" ]]; then
    license_badge="![License](https://img.shields.io/badge/license-MIT-green)"
    license_section="## License\\n\\nThis project is licensed under the MIT License."
    contributing_section="## Contributing\\n\\nContributions are welcome! Please submit a Pull Request."
  fi

  # Files to process (excluding .git, scripts, etc.)
  local files_to_process=$(find . -type f \
    -not -path "./.git/*" \
    -not -path "./scripts/*" \
    -not -path "./.claude/*" \
    -not -path "./Brewfile" \
    -not -path "./README.md" \
    -not -name "*.xcodeproj" \
    -not -name ".DS_Store")

  # Perform replacements on each file
  for file in $files_to_process; do
    if grep -q "{{" "$file" 2>/dev/null; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed
        sed -i '' \
          -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
          -e "s|{{PROJECT_NAME_LOWER}}|$project_name_lower|g" \
          -e "s|{{BUNDLE_ID_ROOT}}|$BUNDLE_ID_ROOT|g" \
          -e "s|{{DEPLOYMENT_TARGET}}|$DEPLOYMENT_TARGET|g" \
          -e "s|{{SWIFT_VERSION}}|$SWIFT_VERSION|g" \
          -e "s|{{SOURCE_LANGUAGE}}|$SOURCE_LANGUAGE|g" \
          -e "s|{{PROJECT_DESCRIPTION}}|An iOS application built with Swift|g" \
          -e "s|{{REPOSITORY_URL}}|https://github.com/yourusername/$project_name_lower|g" \
          -e "s|{{LICENSE_BADGE}}|$license_badge|g" \
          -e "s|{{LICENSE_SECTION}}|$license_section|g" \
          -e "s|{{CONTRIBUTING_SECTION}}|$contributing_section|g" \
          "$file"
      else
        # GNU sed
        sed -i \
          -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
          -e "s|{{PROJECT_NAME_LOWER}}|$project_name_lower|g" \
          -e "s|{{BUNDLE_ID_ROOT}}|$BUNDLE_ID_ROOT|g" \
          -e "s|{{DEPLOYMENT_TARGET}}|$DEPLOYMENT_TARGET|g" \
          -e "s|{{SWIFT_VERSION}}|$SWIFT_VERSION|g" \
          -e "s|{{SOURCE_LANGUAGE}}|$SOURCE_LANGUAGE|g" \
          -e "s|{{PROJECT_DESCRIPTION}}|An iOS application built with Swift|g" \
          -e "s|{{REPOSITORY_URL}}|https://github.com/yourusername/$project_name_lower|g" \
          -e "s|{{LICENSE_BADGE}}|$license_badge|g" \
          -e "s|{{LICENSE_SECTION}}|$license_section|g" \
          -e "s|{{CONTRIBUTING_SECTION}}|$contributing_section|g" \
          "$file"
      fi
      log_success "Processed: $file"
    fi
  done

  log_success "Placeholder replacement complete"
}

rename_directories() {
  log_info "Renaming project directories..."

  # Rename directories from MyProject to actual project name
  if [[ -d "MyProject" ]]; then
    mv "MyProject" "$PROJECT_NAME"
    log_success "Renamed MyProject → $PROJECT_NAME"
  fi

  if [[ -d "MyProjectTests" ]]; then
    mv "MyProjectTests" "${PROJECT_NAME}Tests"
    log_success "Renamed MyProjectTests → ${PROJECT_NAME}Tests"
  fi

  if [[ -d "MyProjectUITests" ]]; then
    mv "MyProjectUITests" "${PROJECT_NAME}UITests"
    log_success "Renamed MyProjectUITests → ${PROJECT_NAME}UITests"
  fi
}

generate_xcode_project() {
  log_info "Generating Xcode project..."

  if ! command_exists xcodegen; then
    log_error "xcodegen not found. Run without --skip-brew first."
    exit 1
  fi

  if ! xcodegen generate; then
    log_error "Failed to generate Xcode project"
    exit 1
  fi

  log_success "Xcode project generated: ${PROJECT_NAME}.xcodeproj"
}

configure_simulators() {
  log_info "Configuring simulators..."

  # Create simulator.yml if it doesn't exist
  if [[ ! -f "simulator.yml" ]]; then
    cat > simulator.yml <<EOF
simulators:
  tests:
    name: iPhone 16 Pro
    os: latest
  ui-tests:
    name: iPhone 16 Pro
    os: latest
EOF
    log_success "Created simulator.yml"
  else
    log_info "simulator.yml already exists, skipping"
  fi
}

setup_git_hooks() {
  if [[ "$USE_GIT_HOOKS" != true ]]; then
    log_info "Skipping git hooks setup"
    return
  fi

  if [[ ! -d ".git" ]]; then
    log_warning "Not a git repository, skipping hooks"
    return
  fi

  log_info "Installing git pre-commit hooks..."

  if [[ -f "scripts/pre-commit.sh" ]]; then
    cp scripts/pre-commit.sh .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    log_success "Pre-commit hook installed"
  else
    log_warning "scripts/pre-commit.sh not found"
  fi
}

create_initial_commit() {
  if [[ "$CREATE_INITIAL_COMMIT" != true ]]; then
    log_info "Skipping initial commit"
    return
  fi

  if [[ ! -d ".git" ]]; then
    log_info "Initializing git repository..."
    git init
    log_success "Git repository initialized"
  fi

  log_info "Creating initial commit..."

  # Add all files
  git add .

  # Create commit
  git commit -m "Initial commit: $PROJECT_NAME

Generated from SwiftProjectTemplate
- iOS $DEPLOYMENT_TARGET+
- Swift $SWIFT_VERSION
- Test framework: $TEST_FRAMEWORK

🤖 Generated with SwiftProjectTemplate" || log_warning "Commit may have failed or no changes to commit"

  log_success "Initial commit created"
}

show_next_steps() {
  echo
  echo "================================================"
  log_success "🎉 Project Setup Complete!"
  echo
  log_info "Project: $PROJECT_NAME"
  log_info "Bundle ID: ${BUNDLE_ID_ROOT}.${PROJECT_NAME}"
  log_info "Deployment Target: iOS $DEPLOYMENT_TARGET+"
  log_info "Swift Version: $SWIFT_VERSION"
  echo
  log_info "Next steps:"
  echo "  1. Open ${PROJECT_NAME}.xcodeproj in Xcode"
  echo "  2. Build and run: ./scripts/build.sh"
  echo "  3. Run tests: ./scripts/test.sh"
  echo "  4. Before committing: ./scripts/preflight.sh"
  echo
  log_info "Development scripts available in scripts/ directory"
  echo "  Run any script with --help for options"
  echo
}

# Main execution
main() {
  echo "🚀 SwiftProjectTemplate Setup"
  echo "=============================="
  echo

  parse_arguments "$@"
  validate_project_name

  install_dependencies
  replace_placeholders
  rename_directories
  configure_simulators
  generate_xcode_project
  setup_git_hooks
  create_initial_commit
  show_next_steps
}

main "$@"
