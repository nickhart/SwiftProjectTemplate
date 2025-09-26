#!/usr/bin/env bash
set -euo pipefail

# Enhanced setup script for SwiftProjectTemplate
# Supports both interactive and CLI modes with intelligent prompting

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
PROJECT_NAME=""
DEPLOYMENT_TARGET="26.0"
SWIFT_VERSION="6.2"
PROJECT_TYPE="private"  # private or public
BUNDLE_ID_ROOT="com.yourcompany"
TEST_FRAMEWORK="swift-testing"  # swift-testing or xctest
SOURCE_LANGUAGE="en"
USE_GIT_HOOKS=true
CREATE_INITIAL_COMMIT=true
GIT_REPOSITORY_AVAILABLE=false
FORCE_OVERWRITE=false
SKIP_BREW=false

# Track which values were set via CLI
CLI_PROJECT_NAME_SET=false
CLI_DEPLOYMENT_TARGET_SET=false
CLI_SWIFT_VERSION_SET=false
CLI_VISIBILITY_SET=false
CLI_BUNDLE_ID_ROOT_SET=false
CLI_TEST_FRAMEWORK_SET=false
CLI_SOURCE_LANGUAGE_SET=false
CLI_GIT_HOOKS_SET=false
CLI_COMMIT_SET=false
CLI_GIT_INIT_SET=false

show_help() {
  cat <<EOF
SwiftProjectTemplate Setup Script

This script sets up a new iOS project from the SwiftProjectTemplate.
It supports both interactive and CLI modes, and will only prompt for
missing information when using CLI arguments.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --project-name <name>         Project name (e.g., "FooApp")
                               Must be a valid Swift identifier
  --bundle-id-root <root>       Bundle identifier root (default: $BUNDLE_ID_ROOT)
                               Format: com.yourname or com.company
  --deployment-target <version> iOS deployment target (default: $DEPLOYMENT_TARGET)
                               Format: X.Y (e.g., 17.0, 18.0, 26.0)
  --swift-version <version>     Swift version (default: $SWIFT_VERSION)
                               Format: X.Y (e.g., 5.9, 5.10, 6.0)
  --test-framework <framework> Test framework (default: $TEST_FRAMEWORK)
                               Options: swift-testing, xctest
  --source-language <code>     Source language for localization (default: $SOURCE_LANGUAGE)
                               Format: ISO 639-1 code (e.g., en, es, fr, de)
  --git-hooks                  Enable git pre-commit hooks (default)
  --no-git-hooks              Disable git pre-commit hooks
  --commit                     Create initial git commit after setup (default)
  --no-commit                  Skip initial git commit after setup
  --public                     Make this a public project (includes LICENSE in README)
  --private                    Make this a private project (default)
  --force                      Overwrite existing files without prompting
  --skip-brew                  Skip Homebrew dependency installation
  --help                       Show this help message

EXAMPLES:
  $0                                        # Interactive mode
  $0 --project-name "MyApp"                 # CLI + interactive for missing info
  $0 --project-name "MyApp" --public        # Mostly CLI, minimal prompts
  $0 --project-name "MyApp" \\
     --deployment-target "26.0" \\
     --swift-version "6.2" \\
     --source-language "en" \\
     --public --force                       # Full CLI mode
  $0 --project-name "MyApp" --no-commit    # Skip initial git commit

VALIDATION:
  - Project name must be a valid Swift identifier (alphanumeric, starts with letter)
  - Deployment target and Swift version must be in X.Y format
  - Conflicting options (--public and --private) will cause an error

WORKFLOW:
  1. Parse CLI arguments and validate for conflicts
  2. Prompt interactively for missing required information
  3. Install Homebrew dependencies (unless --skip-brew)
  4. Generate all configuration files from templates
  5. Create MVVM folder structure
  6. Create Resources with localization and asset catalogs
  7. Generate Xcode project with XcodeGen
  8. Configure simulators with intelligent defaults
  9. Verify or create git repository (offers to run 'git init' if not in a repository)
  10. Set up git pre-commit hooks (if git repository available)
  11. Create initial git commit with project details (unless --no-commit)
  12. Display next steps

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project-name)
        if [[ -z "${2:-}" ]]; then
          log_error "Option --project-name requires a value"
          exit 1
        fi
        PROJECT_NAME="$2"
        CLI_PROJECT_NAME_SET=true
        shift 2
        ;;
      --bundle-id-root)
        if [[ -z "${2:-}" ]]; then
          log_error "Option --bundle-id-root requires a value"
          exit 1
        fi
        BUNDLE_ID_ROOT="$2"
        CLI_BUNDLE_ID_ROOT_SET=true
        shift 2
        ;;
      --deployment-target)
        if [[ -z "${2:-}" ]]; then
          log_error "Option --deployment-target requires a value"
          exit 1
        fi
        DEPLOYMENT_TARGET="$2"
        CLI_DEPLOYMENT_TARGET_SET=true
        shift 2
        ;;
      --swift-version)
        if [[ -z "${2:-}" ]]; then
          log_error "Option --swift-version requires a value"
          exit 1
        fi
        SWIFT_VERSION="$2"
        CLI_SWIFT_VERSION_SET=true
        shift 2
        ;;
      --test-framework)
        if [[ -z "${2:-}" ]]; then
          log_error "Option --test-framework requires a value"
          exit 1
        fi
        if [[ "$2" != "swift-testing" && "$2" != "xctest" ]]; then
          log_error "Invalid test framework: $2. Must be 'swift-testing' or 'xctest'"
          exit 1
        fi
        TEST_FRAMEWORK="$2"
        CLI_TEST_FRAMEWORK_SET=true
        shift 2
        ;;
      --source-language)
        if [[ -z "${2:-}" ]]; then
          log_error "Option --source-language requires a value"
          exit 1
        fi
        SOURCE_LANGUAGE="$2"
        CLI_SOURCE_LANGUAGE_SET=true
        shift 2
        ;;
      --git-hooks)
        USE_GIT_HOOKS=true
        CLI_GIT_HOOKS_SET=true
        shift
        ;;
      --no-git-hooks)
        USE_GIT_HOOKS=false
        CLI_GIT_HOOKS_SET=true
        shift
        ;;
      --commit)
        CREATE_INITIAL_COMMIT=true
        CLI_COMMIT_SET=true
        shift
        ;;
      --no-commit)
        CREATE_INITIAL_COMMIT=false
        CLI_COMMIT_SET=true
        shift
        ;;
      --public)
        if [[ "$PROJECT_TYPE" == "private" ]]; then
          PROJECT_TYPE="public"
        else
          log_error "Conflicting options: --public specified but PROJECT_TYPE is already '$PROJECT_TYPE'"
          exit 1
        fi
        CLI_VISIBILITY_SET=true
        shift
        ;;
      --private)
        if [[ "$PROJECT_TYPE" == "public" ]]; then
          log_error "Conflicting options: --private specified but --public was already set"
          exit 1
        fi
        PROJECT_TYPE="private"
        CLI_VISIBILITY_SET=true
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

validate_inputs() {
  local has_errors=false

  # Validate project name
  if [[ -n "$PROJECT_NAME" ]]; then
    if ! validate_project_name "$PROJECT_NAME"; then
      log_error "Invalid project name: '$PROJECT_NAME'"
      log_info "Project name must:"
      log_info "  - Start with a letter (A-Z, a-z)"
      log_info "  - Contain only alphanumeric characters"
      log_info "  - Be a valid Swift identifier"
      log_info "Examples: MyApp, FooApp, TimeTracker"
      has_errors=true
    fi
  fi

  # Validate bundle ID root
  if [[ -n "$BUNDLE_ID_ROOT" ]]; then
    if ! validate_bundle_id_root "$BUNDLE_ID_ROOT"; then
      log_error "Invalid bundle ID root: '$BUNDLE_ID_ROOT'"
      log_info "Bundle ID root must be in reverse domain format"
      log_info "Examples: com.yourname, com.company, io.github.username"
      has_errors=true
    fi
  fi

  # Validate deployment target
  if ! validate_ios_version "$DEPLOYMENT_TARGET"; then
    log_error "Invalid deployment target: '$DEPLOYMENT_TARGET'"
    log_info "Deployment target must be in format X.Y (e.g., 17.0, 18.0, 26.0)"
    has_errors=true
  fi

  # Validate Swift version
  if ! validate_swift_version "$SWIFT_VERSION"; then
    log_error "Invalid Swift version: '$SWIFT_VERSION'"
    log_info "Swift version must be in format X.Y (e.g., 5.9, 5.10, 6.0)"
    has_errors=true
  fi

  if $has_errors; then
    exit 1
  fi
}

prompt_for_missing_info() {
  # Only prompt for project name if not provided via CLI
  if [[ "$CLI_PROJECT_NAME_SET" == false ]]; then
    while true; do
      echo
      read -p "Enter project name (e.g., MyApp): " PROJECT_NAME
      if validate_project_name "$PROJECT_NAME"; then
        break
      else
        log_error "Invalid project name. Must start with a letter and contain only alphanumeric characters."
      fi
    done
  fi

  # Only prompt for bundle ID root if not provided via CLI
  if [[ "$CLI_BUNDLE_ID_ROOT_SET" == false ]]; then
    while true; do
      echo
      read -p "Bundle ID root (default: $BUNDLE_ID_ROOT): " input_bundle_id_root
      if [[ -n "$input_bundle_id_root" ]]; then
        if validate_bundle_id_root "$input_bundle_id_root"; then
          BUNDLE_ID_ROOT="$input_bundle_id_root"
          break
        else
          log_error "Invalid bundle ID root. Use reverse domain format (e.g., com.yourname)"
        fi
      else
        break  # Use default
      fi
    done
  fi

  # Only prompt for deployment target if not provided via CLI
  if [[ "$CLI_DEPLOYMENT_TARGET_SET" == false ]]; then
    echo
    read -p "iOS deployment target (default: $DEPLOYMENT_TARGET): " input_deployment_target
    if [[ -n "$input_deployment_target" ]]; then
      DEPLOYMENT_TARGET="$input_deployment_target"
      if ! validate_ios_version "$DEPLOYMENT_TARGET"; then
        log_error "Invalid deployment target format. Using default: $DEPLOYMENT_TARGET"
        DEPLOYMENT_TARGET="26.0"
      fi
    fi
  fi

  # Only prompt for Swift version if not provided via CLI
  if [[ "$CLI_SWIFT_VERSION_SET" == false ]]; then
    echo
    read -p "Swift version (default: $SWIFT_VERSION): " input_swift_version
    if [[ -n "$input_swift_version" ]]; then
      SWIFT_VERSION="$input_swift_version"
      if ! validate_swift_version "$SWIFT_VERSION"; then
        log_error "Invalid Swift version format. Using default: $SWIFT_VERSION"
        SWIFT_VERSION="6.2"
      fi
    fi
  fi

  # Only prompt for test framework if not provided via CLI
  if [[ "$CLI_TEST_FRAMEWORK_SET" == false ]]; then
    echo
    while true; do
      read -p "Test framework (swift-testing/xctest, default: $TEST_FRAMEWORK): " input_test_framework
      if [[ -z "$input_test_framework" ]]; then
        break  # Use default
      elif [[ "$input_test_framework" == "swift-testing" || "$input_test_framework" == "xctest" ]]; then
        TEST_FRAMEWORK="$input_test_framework"
        break
      else
        log_error "Invalid test framework. Choose 'swift-testing' or 'xctest'"
      fi
    done
  fi

  # Only prompt for source language if not provided via CLI
  if [[ "$CLI_SOURCE_LANGUAGE_SET" == false ]]; then
    echo
    read -p "Source language for localization (default: $SOURCE_LANGUAGE): " input_source_language
    if [[ -n "$input_source_language" ]]; then
      SOURCE_LANGUAGE="$input_source_language"
    fi
  fi

  # Only prompt for git hooks if not provided via CLI
  if [[ "$CLI_GIT_HOOKS_SET" == false ]]; then
    echo
    while true; do
      read -p "Enable git pre-commit hooks? (Y/n): " yn
      case $yn in
        [Yy]*|"") USE_GIT_HOOKS=true; break;;
        [Nn]*) USE_GIT_HOOKS=false; break;;
        *) log_error "Please answer y or n";;
      esac
    done
  fi

  # Ask about project visibility if not specified via CLI
  if [[ "$CLI_VISIBILITY_SET" == false ]]; then
    echo
    while true; do
      read -p "Is this a public project? (y/N): " yn
      case $yn in
        [Yy]* ) PROJECT_TYPE="public"; break;;
        [Nn]* | "" ) PROJECT_TYPE="private"; break;;
        * ) echo "Please answer yes or no.";;
      esac
    done
  fi

  # Handle git repository initialization if not already in one and git features are needed
  if ! is_git_repo && ($USE_GIT_HOOKS || $CREATE_INITIAL_COMMIT) && [[ "$CLI_GIT_INIT_SET" == false ]]; then
    echo
    log_warning "Not in a git repository"
    while true; do
      read -p "Would you like to initialize a git repository? (Y/n): " yn
      case $yn in
        [Yy]*|"")
          log_info "Will initialize git repository during setup"
          GIT_REPOSITORY_AVAILABLE=true
          break
          ;;
        [Nn]*)
          log_info "Git repository will not be initialized"
          log_info "Git hooks and initial commit will be skipped"
          GIT_REPOSITORY_AVAILABLE=false
          break
          ;;
        *) echo "Please answer yes or no.";;
      esac
    done
  elif is_git_repo; then
    GIT_REPOSITORY_AVAILABLE=true
  else
    GIT_REPOSITORY_AVAILABLE=false
  fi
}

detect_architecture() {
  # Detect Mac architecture for simulator settings
  case "$(uname -m)" in
    arm64) echo "arm64" ;;
    x86_64) echo "x86_64" ;;
    *) echo "arm64" ;; # Default to arm64 for Apple Silicon
  esac
}

install_dependencies() {
  if $SKIP_BREW; then
    log_info "Skipping Homebrew dependency installation (--skip-brew specified)"
    return
  fi

  log_info "Installing Homebrew dependencies..."

  if ! command_exists brew; then
    log_error "Homebrew is not installed"
    log_info "Please install Homebrew first: https://brew.sh"
    log_info "Or run this script with --skip-brew to skip dependency installation"
    exit 1
  fi

  if ! brew bundle install --file="$ROOT_DIR/Brewfile"; then
    log_error "Failed to install Homebrew dependencies"
    log_info "You can retry with: brew bundle install --file=./Brewfile"
    exit 1
  fi

  log_success "Dependencies installed successfully"
}

generate_template_files() {
  log_info "Generating project files from templates..."

  local templates_dir="$ROOT_DIR/templates"
  local project_name_lower
  project_name_lower=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')
  local simulator_arch
  simulator_arch=$(detect_architecture)

  # Prepare template variables
  local template_vars=(
    "PROJECT_NAME=$PROJECT_NAME"
    "PROJECT_NAME_LOWER=$project_name_lower"
    "BUNDLE_ID_ROOT=$BUNDLE_ID_ROOT"
    "DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET"
    "SWIFT_VERSION=$SWIFT_VERSION"
    "SIMULATOR_ARCH=$simulator_arch"
    "PROJECT_DESCRIPTION=A new iOS application built with SwiftUI"
    "ARCHITECTURE=SwiftUI + MVVM"
    "ARCHITECTURE_DESCRIPTION=Modern SwiftUI app with Model-View-ViewModel architecture"
    "PATTERN_DESCRIPTION=ViewModels handle business logic, Views handle UI"
    "KEY_COMPONENTS=- App entry point\\n- Core Data stack\\n- Main ViewModels\\n- SwiftUI Views"
    "DATA_FLOW_DESCRIPTION=1. Views observe ViewModels\\n2. ViewModels update Models\\n3. Models notify ViewModels of changes\\n4. ViewModels update Views"
    "PROJECT_SPECIFIC_FEATURES=- SwiftUI interface\\n- Core Data persistence\\n- MVVM architecture"
  )

  # Add project type specific variables
  if [[ "$PROJECT_TYPE" == "public" ]]; then
    template_vars+=(
      "LICENSE_BADGE=![License](https://img.shields.io/badge/license-MIT-green)"
      "LICENSE_SECTION=## License\\n\\nThis project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details."
      "CONTRIBUTING_SECTION=## Contributing\\n\\nContributions are welcome! Please feel free to submit a Pull Request."
      "REPOSITORY_URL=https://github.com/yourusername/$project_name_lower"
    )
  else
    template_vars+=(
      "LICENSE_BADGE="
      "LICENSE_SECTION="
      "CONTRIBUTING_SECTION="
      "REPOSITORY_URL=https://github.com/yourusername/$project_name_lower"
    )
  fi

  # Generate each template file
  local files_to_generate=(
    "project.yml.template:project.yml"
    ".swiftlint.yml.template:.swiftlint.yml"
    ".swiftformat.template:.swiftformat"
    "README.md.template:README.md"
  )

  for file_mapping in "${files_to_generate[@]}"; do
    local template_file="${file_mapping%:*}"
    local output_file="${file_mapping#*:}"
    local template_path="$templates_dir/$template_file"
    local output_path="$ROOT_DIR/$output_file"

    # Check if output file exists and handle overwrite
    # Force overwrite for template-specific files that should always be regenerated
    local force_overwrite_files=("README.md")
    local should_force_overwrite=false

    for force_file in "${force_overwrite_files[@]}"; do
      if [[ "$output_file" == "$force_file" ]]; then
        should_force_overwrite=true
        break
      fi
    done

    if [[ -f "$output_path" && "$FORCE_OVERWRITE" != true && "$should_force_overwrite" != true ]]; then
      log_warning "File $output_file already exists"
      while true; do
        read -p "Overwrite $output_file? (y/n): " yn
        case $yn in
          [Yy]* ) break;;
          [Nn]* )
            log_info "Skipping $output_file"
            continue 2;;
          * ) echo "Please answer yes or no.";;
        esac
      done
    elif [[ -f "$output_path" && "$should_force_overwrite" == true ]]; then
      log_info "Force overwriting $output_file (template-specific file)"
    fi

    # Generate file from template
    if [[ -f "$template_path" ]]; then
      replace_template_vars "$template_path" "$output_path" "${template_vars[@]}"
      log_success "Generated $output_file"
    else
      log_warning "Template $template_file not found, skipping"
    fi
  done

}

create_project_structure() {
  log_info "Creating MVVM project structure..."

  # Create main app directories
  local app_dirs=(
    "$PROJECT_NAME/Models"
    "$PROJECT_NAME/Views"
    "$PROJECT_NAME/ViewModels"
    "$PROJECT_NAME/Services"
    "$PROJECT_NAME/Extensions"
    "$PROJECT_NAME/Helpers"
  )

  # Create test directories
  local test_dirs=(
    "${PROJECT_NAME}Tests/Models"
    "${PROJECT_NAME}Tests/Views"
    "${PROJECT_NAME}Tests/ViewModels"
    "${PROJECT_NAME}Tests/Services"
    "${PROJECT_NAME}UITests"
  )

  # Create all directories
  for dir in "${app_dirs[@]}" "${test_dirs[@]}"; do
    mkdir -p "$dir"
    # Add .gitkeep to empty directories
    touch "$dir/.gitkeep"
    log_success "Created $dir/"
  done

  # Create basic app entry point
  local app_file="$PROJECT_NAME/${PROJECT_NAME}App.swift"
  if [[ ! -f "$app_file" || "$FORCE_OVERWRITE" == true ]]; then
    cat > "$app_file" <<EOF
import SwiftUI

@main
struct ${PROJECT_NAME}App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF
    log_success "Created ${PROJECT_NAME}App.swift"
  fi

  # Create basic ContentView
  local content_view_file="$PROJECT_NAME/Views/ContentView.swift"
  if [[ ! -f "$content_view_file" || "$FORCE_OVERWRITE" == true ]]; then
    cat > "$content_view_file" <<EOF
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "swift")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Welcome to $PROJECT_NAME!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Your iOS app is ready to build amazing things.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Get Started") {
                    print("Hello from $PROJECT_NAME!")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("$PROJECT_NAME")
        }
    }
}

#Preview {
    ContentView()
}
EOF
    log_success "Created ContentView.swift"
  fi

  # Create a sample ViewModel
  local main_viewmodel_file="$PROJECT_NAME/ViewModels/MainViewModel.swift"
  if [[ ! -f "$main_viewmodel_file" || "$FORCE_OVERWRITE" == true ]]; then
    cat > "$main_viewmodel_file" <<EOF
import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var message = "Hello from $PROJECT_NAME!"
    @Published var isLoading = false

    func refreshData() {
        isLoading = true

        // Simulate async work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.message = "Data refreshed at \(Date().formatted(date: .omitted, time: .shortened))"
            self.isLoading = false
        }
    }
}
EOF
    log_success "Created MainViewModel.swift"
  fi

  # Create basic ViewModel test based on chosen framework
  local viewmodel_test_file="${PROJECT_NAME}Tests/ViewModels/MainViewModelTests.swift"
  if [[ ! -f "$viewmodel_test_file" || "$FORCE_OVERWRITE" == true ]]; then
    mkdir -p "${PROJECT_NAME}Tests/ViewModels"

    if [[ "$TEST_FRAMEWORK" == "swift-testing" ]]; then
      cat > "$viewmodel_test_file" <<EOF
import Testing
import Combine
@testable import $PROJECT_NAME

@MainActor
struct MainViewModelTests {

    @Test("Initial state should be correct")
    func initialState() {
        let viewModel = MainViewModel()
        #expect(viewModel.message == "Hello from $PROJECT_NAME!")
        #expect(viewModel.isLoading == false)
    }

    @Test("Refresh data should update message and loading state")
    func refreshData() async {
        let viewModel = MainViewModel()

        // Start refresh
        viewModel.refreshData()
        #expect(viewModel.isLoading == true)

        // Wait for completion
        try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds

        #expect(viewModel.isLoading == false)
        #expect(viewModel.message.contains("Data refreshed"))
    }
}
EOF
    else
      cat > "$viewmodel_test_file" <<EOF
import XCTest
import Combine
@testable import $PROJECT_NAME

@MainActor
final class MainViewModelTests: XCTestCase {
    var viewModel: MainViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = MainViewModel()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }

    func testInitialState() throws {
        XCTAssertEqual(viewModel.message, "Hello from $PROJECT_NAME!")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testRefreshData() throws {
        let expectation = XCTestExpectation(description: "Data refresh completes")

        viewModel.\$message
            .dropFirst() // Skip initial value
            .sink { message in
                XCTAssertTrue(message.contains("Data refreshed"))
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.refreshData()
        XCTAssertTrue(viewModel.isLoading)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(viewModel.isLoading)
    }
}
EOF
    fi
    log_success "Created MainViewModelTests.swift ($TEST_FRAMEWORK)"
  fi

  # Create basic UI test
  local ui_test_file="${PROJECT_NAME}UITests/${PROJECT_NAME}UITests.swift"
  if [[ ! -f "$ui_test_file" || "$FORCE_OVERWRITE" == true ]]; then
    cat > "$ui_test_file" <<EOF
import XCTest

final class ${PROJECT_NAME}UITests: XCTestCase {
    nonisolated(unsafe) var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testAppLaunches() throws {
        // Test that the app launches and shows the main content
        let navigationTitle = app.navigationBars["$PROJECT_NAME"]
        XCTAssertTrue(navigationTitle.exists)

        let welcomeText = app.staticTexts["Welcome to $PROJECT_NAME!"]
        XCTAssertTrue(welcomeText.exists)

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists)
    }

    @MainActor
    func testGetStartedButton() throws {
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists)

        getStartedButton.tap()
        // Add assertions for what should happen when button is tapped
    }
}
EOF
    log_success "Created ${PROJECT_NAME}UITests.swift"
  fi

  # Create Info.plist (required by XcodeGen even though properties are in project.yml)
  local info_plist_file="$PROJECT_NAME/Info.plist"
  if [[ ! -f "$info_plist_file" || "$FORCE_OVERWRITE" == true ]]; then
    cat > "$info_plist_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>\$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>\$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
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
                    <string>\$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
EOF
    log_success "Created Info.plist"
  fi
}

create_resources_structure() {
  log_info "Creating Resources with localization and asset catalogs..."

  # Create Resources directory if it doesn't exist
  mkdir -p "$PROJECT_NAME/Resources"

  # Create Localizable.xcstrings
  local localizable_file="$PROJECT_NAME/Resources/Localizable.xcstrings"
  if [[ ! -f "$localizable_file" || "$FORCE_OVERWRITE" == true ]]; then
    cat > "$localizable_file" <<EOF
{
  "sourceLanguage" : "$SOURCE_LANGUAGE",
  "strings" : {
  },
  "version" : "1.1"
}
EOF
    log_success "Created Localizable.xcstrings with source language: $SOURCE_LANGUAGE"
  fi

  # Create Asset Catalog structure
  local assets_dir="$PROJECT_NAME/Resources/Assets.xcassets"
  mkdir -p "$assets_dir"

  # Main Assets.xcassets Contents.json
  cat > "$assets_dir/Contents.json" <<EOF
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  # Create AppIcon.appiconset
  local appicon_dir="$assets_dir/AppIcon.appiconset"
  mkdir -p "$appicon_dir"
  cat > "$appicon_dir/Contents.json" <<EOF
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  # Create AccentColor.colorset
  local accentcolor_dir="$assets_dir/AccentColor.colorset"
  mkdir -p "$accentcolor_dir"
  cat > "$accentcolor_dir/Contents.json" <<EOF
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  log_success "Created Assets.xcassets with AppIcon and AccentColor"
}

generate_xcode_project() {
  log_info "Generating Xcode project with XcodeGen..."

  if ! command_exists xcodegen; then
    log_error "XcodeGen is not installed"
    log_info "Install it with: brew install xcodegen"
    exit 1
  fi

  if xcodegen generate; then
    log_success "Xcode project generated successfully"
  else
    log_error "Failed to generate Xcode project"
    log_info "Check project.yml for configuration errors"
    exit 1
  fi
}

setup_default_simulators() {
  log_info "Configuring default simulators..."

  # Try to find a good default iPhone for tests
  local default_iphone=""
  local default_ipad=""

  # List of preferred iPhone devices (newest first)
  local preferred_iphones=(
    "iPhone 17 Pro"
    "iPhone 17"
    "iPhone 16 Pro"
    "iPhone 16"
    "iPhone 15 Pro"
    "iPhone 15"
    "iPhone 14 Pro"
    "iPhone 14"
  )

  # List of preferred iPad devices (newest first)
  local preferred_ipads=(
    "iPad Air 11-inch (M3)"
    "iPad Pro 11-inch (M4)"
    "iPad Air 11-inch (M2)"
    "iPad Pro 12.9-inch (6th generation)"
    "iPad Air (5th generation)"
  )

  # Find first available iPhone
  for iphone in "${preferred_iphones[@]}"; do
    if "$ROOT_DIR/scripts/simulator.sh" optimal-os "$iphone" >/dev/null 2>&1; then
      default_iphone="$iphone"
      break
    fi
  done

  # Find first available iPad
  for ipad in "${preferred_ipads[@]}"; do
    if "$ROOT_DIR/scripts/simulator.sh" optimal-os "$ipad" >/dev/null 2>&1; then
      default_ipad="$ipad"
      break
    fi
  done

  # Configure unit tests simulator
  if [[ -n "$default_iphone" ]]; then
    log_info "Configuring unit tests with: $default_iphone"
    if "$ROOT_DIR/scripts/simulator.sh" config-tests "$default_iphone" --yes; then
      log_success "Unit tests simulator configured"
    else
      log_warning "Failed to configure unit tests simulator"
    fi
  else
    log_warning "No suitable iPhone simulator found for unit tests"
    log_info "You can configure manually with: ./scripts/simulator.sh config-tests \"<device_name>\""
  fi

  # Configure UI tests simulator (prefer iPad if available, fallback to iPhone)
  local ui_device="$default_ipad"
  if [[ -z "$ui_device" ]]; then
    ui_device="$default_iphone"
  fi

  if [[ -n "$ui_device" ]]; then
    log_info "Configuring UI tests with: $ui_device"
    if "$ROOT_DIR/scripts/simulator.sh" config-ui-tests "$ui_device" --yes; then
      log_success "UI tests simulator configured"
    else
      log_warning "Failed to configure UI tests simulator"
    fi
  else
    log_warning "No suitable simulator found for UI tests"
    log_info "You can configure manually with: ./scripts/simulator.sh config-ui-tests \"<device_name>\""
  fi

  echo
  log_info "Simulator configuration complete. To view current settings:"
  echo "  ./scripts/simulator.sh show-config"
}

verify_or_create_git_repository() {
  # If already in a git repository, nothing to do
  if is_git_repo; then
    return
  fi

  # If git repository should be created (determined during prompting)
  if $GIT_REPOSITORY_AVAILABLE; then
    log_info "Initializing git repository with 'main' as default branch..."

    # Try modern git init with --initial-branch, fallback for older git versions
    if git init --initial-branch=main 2>/dev/null; then
      log_success "Git repository initialized with 'main' branch"
    elif git init 2>/dev/null; then
      # Older git version - rename default branch to main
      git checkout -b main 2>/dev/null || true
      log_success "Git repository initialized and switched to 'main' branch"
    else
      log_error "Failed to initialize git repository"
      GIT_REPOSITORY_AVAILABLE=false
    fi
  fi
}

setup_git_hooks() {
  if ! $USE_GIT_HOOKS; then
    log_info "Git hooks disabled, skipping git hook setup"
    return
  fi

  if ! $GIT_REPOSITORY_AVAILABLE; then
    log_info "Git repository not available, skipping git hook setup"
    return
  fi

  log_info "Setting up git pre-commit hook..."

  local hooks_dir="$ROOT_DIR/.git/hooks"
  local pre_commit_hook="$hooks_dir/pre-commit"

  mkdir -p "$hooks_dir"

  cat > "$pre_commit_hook" <<EOF
#!/usr/bin/env bash
exec "$ROOT_DIR/scripts/pre-commit.sh" "\$@"
EOF

  chmod +x "$pre_commit_hook"
  log_success "Git pre-commit hook installed"
  log_info "Hook will run formatting, linting, and build checks before commits"
}

create_initial_commit() {
  if ! $CREATE_INITIAL_COMMIT; then
    log_info "Initial commit disabled, skipping git commit"
    return
  fi

  if ! $GIT_REPOSITORY_AVAILABLE; then
    log_info "Git repository not available, skipping initial commit"
    return
  fi

  log_info "Creating initial git commit..."

  # Add all generated files
  git add . 2>/dev/null

  # Check if there are files to commit
  if git diff --cached --quiet; then
    log_warning "No changes to commit"
    return
  fi

  # Create initial commit with descriptive message
  local commit_message="Initial project setup

Generated iOS project using SwiftProjectTemplate with:
- Project: $PROJECT_NAME
- Bundle ID: ${BUNDLE_ID_ROOT}.${PROJECT_NAME}
- iOS Deployment Target: $DEPLOYMENT_TARGET
- Swift Version: $SWIFT_VERSION
- Test Framework: $TEST_FRAMEWORK
- Source Language: $SOURCE_LANGUAGE"

  if git commit -m "$commit_message" 2>/dev/null; then
    log_success "Initial commit created successfully"
    log_info "You can view the commit with: git log --oneline -1"
  else
    log_error "Failed to create initial commit"
    log_info "You may need to configure git user settings:"
    echo "  git config --global user.name \"Your Name\""
    echo "  git config --global user.email \"your.email@example.com\""
  fi
}

display_next_steps() {
  log_success "🎉 Project setup complete!"
  echo
  echo "Project: $PROJECT_NAME"
  echo "iOS Deployment Target: $DEPLOYMENT_TARGET"
  echo "Swift Version: $SWIFT_VERSION"
  echo "Source Language: $SOURCE_LANGUAGE"
  echo "Project Type: $PROJECT_TYPE"
  echo
  log_info "Next steps:"
  echo "  1. [optional] Reconfigure simulators for building and testing:"
  echo "     ./scripts/simulator.sh list"
  echo "     ./scripts/simulator.sh config-tests \"iPhone 16 Pro\""
  echo "  2. [optional] run the preflight script to verify everything builds and tests with 0 errors!"
  echo "     ./scripts/preflight.sh"
  echo "  3. Open $PROJECT_NAME.xcodeproj in Xcode"
  echo "  4. Start building your app!"
  echo
  log_info "Available commands:"
  echo "  ./scripts/build.sh                    # Build for simulator"
  echo "  ./scripts/test.sh                     # Run tests"
  echo "  ./scripts/lint.sh --fix               # Fix linting issues"
  echo "  ./scripts/format.sh --fix             # Fix formatting"
  echo "  ./scripts/preflight.sh                # Full CI check"
  echo "  ./scripts/simulator.sh list           # List available simulators"
  echo
  log_info "Need help? Check README.md for guidance."
}

# Main execution
main() {
  log_info "SwiftProjectTemplate Setup"
  echo

  parse_arguments "$@"
  validate_inputs
  prompt_for_missing_info
  validate_inputs  # Validate again after interactive input

  log_info "Setting up project with:"
  log_info "  Project Name: $PROJECT_NAME"
  log_info "  Bundle Identifier: ${BUNDLE_ID_ROOT}.$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
  log_info "  Deployment Target: iOS $DEPLOYMENT_TARGET"
  log_info "  Swift Version: $SWIFT_VERSION"
  log_info "  Test Framework: $TEST_FRAMEWORK"
  log_info "  Source Language: $SOURCE_LANGUAGE"
  log_info "  Git Hooks: $(if $USE_GIT_HOOKS; then echo "enabled"; else echo "disabled"; fi)"
  log_info "  Project Type: $PROJECT_TYPE"
  echo

  install_dependencies
  generate_template_files
  create_project_structure
  create_resources_structure
  generate_xcode_project
  setup_default_simulators
  verify_or_create_git_repository
  setup_git_hooks
  create_initial_commit

  display_next_steps
}

# Run main function with all arguments
main "$@"