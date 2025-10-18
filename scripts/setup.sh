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
DEPLOYMENT_TARGET="26.0"
SWIFT_VERSION="6.2"
PROJECT_TYPE="private"
BUNDLE_ID_ROOT="com.yourcompany"
TEST_FRAMEWORK="swift-testing"
SOURCE_LANGUAGE="en"
USE_GIT_HOOKS=true
CREATE_INITIAL_COMMIT=true
FORCE_OVERWRITE=false
SKIP_BREW=false
GENERATE_MINIMAL=false
STRUCTURE="mvvm"  # mvvm, clean, or none
PROJECT_MODE=""   # Will be set to "adopt" or "generate"

show_help() {
  cat <<EOF
SwiftProjectTemplate Setup Script

Configures the template for your project. Supports two modes:
1. ADOPT mode: Integrate with existing Xcode project
2. GENERATE mode: Create minimal project from scratch

USAGE:
  $0 --project-name <name> [OPTIONS]

PRIMARY OPTIONS:
  --project-name <name>         Project name (required)
  --generate-minimal            Create minimal project (default: adopt existing .xcodeproj)
  --structure <type>            Directory structure: mvvm, clean, or none (default: mvvm)

CONFIGURATION OPTIONS:
  --bundle-id-root <root>       Bundle identifier root (default: $BUNDLE_ID_ROOT)
  --deployment-target <version> iOS deployment target (default: $DEPLOYMENT_TARGET)
  --swift-version <version>     Swift version (default: $SWIFT_VERSION)
  --test-framework <framework>  Test framework: swift-testing or xctest (default: $TEST_FRAMEWORK)
  --source-language <code>      Source language (default: $SOURCE_LANGUAGE)

PROJECT OPTIONS:
  --public                      Make this a public project
  --private                     Make this a private project (default)

GIT OPTIONS:
  --git-hooks                   Enable git pre-commit hooks (default)
  --no-git-hooks                Disable git pre-commit hooks
  --commit                      Create initial git commit (default)
  --no-commit                   Skip initial git commit

OTHER OPTIONS:
  --force                       Overwrite existing files without prompting
  --skip-brew                   Skip Homebrew dependency installation
  --help                        Show this help message

EXAMPLES:
  # Adopt existing Xcode project (primary workflow)
  $0 --project-name "MyApp"

  # Generate minimal project for quick start
  $0 --project-name "MyApp" --generate-minimal

  # Generate with clean structure (no MVVM directories)
  $0 --project-name "MyApp" --generate-minimal --structure clean

  # Public project with custom config
  $0 --project-name "MyApp" --public --deployment-target 17.0

WORKFLOWS:
  1. Xcode-first (recommended):
     - Create project in Xcode
     - Clone template into project directory
     - Run: ./scripts/setup.sh --project-name YourApp

  2. Template-first (quick start):
     - Clone template
     - Run: ./scripts/setup.sh --project-name YourApp --generate-minimal
     - Open generated .xcodeproj in Xcode

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
      --generate-minimal)
        GENERATE_MINIMAL=true
        shift
        ;;
      --structure)
        STRUCTURE="$2"
        shift 2
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

  # Validate structure option
  if [[ "$STRUCTURE" != "mvvm" && "$STRUCTURE" != "clean" && "$STRUCTURE" != "none" ]]; then
    log_error "Invalid structure: $STRUCTURE. Must be 'mvvm', 'clean', or 'none'"
    exit 1
  fi
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

detect_project_mode() {
  log_info "Detecting project mode..."

  # Check if .xcodeproj exists
  local xcodeproj_path="${PROJECT_NAME}.xcodeproj"

  if [[ -d "$xcodeproj_path" ]]; then
    if [[ "$GENERATE_MINIMAL" == true ]]; then
      log_error "Project already exists at $xcodeproj_path"
      log_error "Cannot use --generate-minimal with existing project"
      exit 1
    fi
    PROJECT_MODE="adopt"
    log_info "Found existing project: $xcodeproj_path"
    log_info "Mode: ADOPT"
  else
    if [[ "$GENERATE_MINIMAL" == false ]]; then
      log_error "No existing project found: $xcodeproj_path"
      echo ""
      log_info "To create a new project, use one of these options:"
      echo "  1. Create project in Xcode first, then run setup again"
      echo "  2. Use --generate-minimal flag to create minimal project"
      echo ""
      echo "Example: $0 --project-name $PROJECT_NAME --generate-minimal"
      exit 1
    fi
    PROJECT_MODE="generate"
    log_info "No existing project found"
    log_info "Mode: GENERATE"
  fi

  echo
}

create_directory_structure() {
  local base_dir="$1"

  log_info "Creating directory structure: $STRUCTURE"

  case "$STRUCTURE" in
    mvvm)
      mkdir -p "$base_dir"/{Models,Views,ViewModels,Services,Extensions,Helpers,Resources}
      touch "$base_dir"/{Models,ViewModels,Services,Extensions,Helpers}/.gitkeep
      log_success "Created MVVM directory structure"
      ;;
    clean)
      mkdir -p "$base_dir/Resources"
      log_success "Created clean directory structure"
      ;;
    none)
      mkdir -p "$base_dir"
      log_success "Created base directory"
      ;;
  esac
}

generate_minimal_project() {
  log_info "Generating minimal project..."

  # Create main app directory
  create_directory_structure "$PROJECT_NAME"

  # Create AppDelegate.swift
  cat > "$PROJECT_NAME/AppDelegate.swift" <<'EOF'
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return true
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
  }

  func application(
    _ application: UIApplication,
    didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {
  }
}
EOF

  # Create SceneDelegate.swift
  cat > "$PROJECT_NAME/SceneDelegate.swift" <<'EOF'
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    let window = UIWindow(windowScene: windowScene)
    let viewController = ViewController()
    window.rootViewController = viewController
    window.makeKeyAndVisible()
    self.window = window
  }
}
EOF

  # Create ViewController.swift in appropriate location
  local view_path="$PROJECT_NAME"
  if [[ "$STRUCTURE" == "mvvm" ]]; then
    view_path="$PROJECT_NAME/Views"
  fi

  cat > "$view_path/ViewController.swift" <<EOF
import UIKit

class ViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let label = UILabel()
    label.text = "Hello, $PROJECT_NAME!"
    label.font = .preferredFont(forTextStyle: .largeTitle)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(label)

    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
    ])
  }
}
EOF

  # Create Info.plist
  cat > "$PROJECT_NAME/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<false/>
		<key>UISceneConfigurations</key>
		<dict>
			<key>UIWindowSceneSessionRoleApplication</key>
			<array>
				<dict>
					<key>UISceneConfigurationName</key>
					<string>Default Configuration</string>
					<key>UISceneDelegateClassName</key>
					<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
				</dict>
			</array>
		</dict>
	</dict>
</dict>
</plist>
EOF

  # Create test targets
  mkdir -p "${PROJECT_NAME}Tests"
  cat > "${PROJECT_NAME}Tests/${PROJECT_NAME}Tests.swift" <<EOF
import Testing
@testable import $PROJECT_NAME

struct ${PROJECT_NAME}Tests {
  @Test func exampleTest() async throws {
    #expect(true)
  }
}
EOF

  mkdir -p "${PROJECT_NAME}UITests"
  cat > "${PROJECT_NAME}UITests/${PROJECT_NAME}UITests.swift" <<EOF
import XCTest

@MainActor
final class ${PROJECT_NAME}UITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.exists)
  }
}
EOF

  log_success "Minimal project generated"
}

adopt_existing_project() {
  log_info "Adopting existing Xcode project..."

  # For now, we'll just verify the project exists and configure tooling around it
  # In the future, we could use xcodegen dump to extract config

  if [[ ! -d "${PROJECT_NAME}.xcodeproj" ]]; then
    log_error "Project ${PROJECT_NAME}.xcodeproj not found"
    exit 1
  fi

  log_success "Existing project verified"
  log_info "Configuring tooling for existing project structure"

  # Create directory structure if requested
  if [[ "$STRUCTURE" != "none" ]]; then
    create_directory_structure "$PROJECT_NAME"
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
    name: iPhone 17 Pro
    os: latest
  ui-tests:
    name: iPhone 17 Pro
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
  detect_project_mode

  install_dependencies
  replace_placeholders

  # Mode-specific operations
  if [[ "$PROJECT_MODE" == "generate" ]]; then
    generate_minimal_project
  elif [[ "$PROJECT_MODE" == "adopt" ]]; then
    adopt_existing_project
  fi

  configure_simulators
  generate_xcode_project
  setup_git_hooks
  create_initial_commit
  show_next_steps
}

main "$@"
