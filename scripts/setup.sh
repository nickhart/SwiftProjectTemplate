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
DEPLOYMENT_TARGET="18.0"
SWIFT_VERSION="5.10"
PROJECT_TYPE="private"  # private or public
FORCE_OVERWRITE=false
SKIP_BREW=false

# Track which values were set via CLI
CLI_PROJECT_NAME_SET=false
CLI_DEPLOYMENT_TARGET_SET=false
CLI_SWIFT_VERSION_SET=false
CLI_VISIBILITY_SET=false

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
  --deployment-target <version> iOS deployment target (default: $DEPLOYMENT_TARGET)
                               Format: X.Y (e.g., 16.0, 17.5, 18.1)
  --swift-version <version>     Swift version (default: $SWIFT_VERSION)
                               Format: X.Y (e.g., 5.9, 5.10, 6.0)
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
     --deployment-target "17.0" \\
     --swift-version "5.9" \\
     --public --force                       # Full CLI mode

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
  6. Generate Xcode project with XcodeGen
  7. Set up git pre-commit hooks
  8. Display next steps

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

  # Validate deployment target
  if ! validate_ios_version "$DEPLOYMENT_TARGET"; then
    log_error "Invalid deployment target: '$DEPLOYMENT_TARGET'"
    log_info "Deployment target must be in format X.Y (e.g., 16.0, 17.5, 18.1)"
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

  # Only prompt for deployment target if not provided via CLI
  if [[ "$CLI_DEPLOYMENT_TARGET_SET" == false ]]; then
    echo
    read -p "iOS deployment target (default: $DEPLOYMENT_TARGET): " input_deployment_target
    if [[ -n "$input_deployment_target" ]]; then
      DEPLOYMENT_TARGET="$input_deployment_target"
      if ! validate_ios_version "$DEPLOYMENT_TARGET"; then
        log_error "Invalid deployment target format. Using default: $DEPLOYMENT_TARGET"
        DEPLOYMENT_TARGET="18.0"
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
        SWIFT_VERSION="5.10"
      fi
    fi
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
    ".gitignore.template:.gitignore"
    "simulator.yml.template:simulator.yml"
    "README.md.template:README.md"
    "CLAUDE.md.template:CLAUDE.md"
    "TODO.md.template:TODO.md"
  )

  for file_mapping in "${files_to_generate[@]}"; do
    local template_file="${file_mapping%:*}"
    local output_file="${file_mapping#*:}"
    local template_path="$templates_dir/$template_file"
    local output_path="$ROOT_DIR/$output_file"

    # Check if output file exists and handle overwrite
    if [[ -f "$output_path" && "$FORCE_OVERWRITE" != true ]]; then
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
    "$PROJECT_NAME/Resources"
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

  # Create basic ViewModel test
  local viewmodel_test_file="${PROJECT_NAME}Tests/ViewModels/MainViewModelTests.swift"
  if [[ ! -f "$viewmodel_test_file" || "$FORCE_OVERWRITE" == true ]]; then
    mkdir -p "${PROJECT_NAME}Tests/ViewModels"
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
        XCTAssertEqual(viewModel.message, "Hello from {{PROJECT_NAME}}!")
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
    log_success "Created MainViewModelTests.swift"
  fi

  # Create basic UI test
  local ui_test_file="${PROJECT_NAME}UITests/${PROJECT_NAME}UITests.swift"
  if [[ ! -f "$ui_test_file" || "$FORCE_OVERWRITE" == true ]]; then
    cat > "$ui_test_file" <<EOF
import XCTest

final class ${PROJECT_NAME}UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppLaunches() throws {
        // Test that the app launches and shows the main content
        let navigationTitle = app.navigationBars["$PROJECT_NAME"]
        XCTAssertTrue(navigationTitle.exists)
        
        let welcomeText = app.staticTexts["Welcome to $PROJECT_NAME!"]
        XCTAssertTrue(welcomeText.exists)
        
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists)
    }
    
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

  # Create Info.plist
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

setup_git_hooks() {
  if ! is_git_repo; then
    log_warning "Not in a git repository, skipping git hook setup"
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
}

display_next_steps() {
  log_success "🎉 Project setup complete!"
  echo
  echo "Project: $PROJECT_NAME"
  echo "iOS Deployment Target: $DEPLOYMENT_TARGET"
  echo "Swift Version: $SWIFT_VERSION"
  echo "Project Type: $PROJECT_TYPE"
  echo
  log_info "Next steps:"
  echo "  1. Open $PROJECT_NAME.xcodeproj in Xcode"
  echo "  2. Update bundle identifier in project.yml if needed"
  echo "  3. Start building your app!"
  echo
  log_info "Available commands:"
  echo "  ./scripts/build.sh                    # Build for simulator"
  echo "  ./scripts/test.sh                     # Run tests"
  echo "  ./scripts/lint.sh --fix               # Fix linting issues"
  echo "  ./scripts/format.sh --fix             # Fix formatting"
  echo "  ./scripts/preflight.sh                # Full CI check"
  echo "  ./scripts/simulator.sh list           # List simulators"
  echo
  log_info "Need help? Check README.md or CLAUDE.md for guidance."
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
  log_info "  Deployment Target: iOS $DEPLOYMENT_TARGET"
  log_info "  Swift Version: $SWIFT_VERSION"
  log_info "  Project Type: $PROJECT_TYPE"
  echo

  install_dependencies
  generate_template_files
  create_project_structure
  generate_xcode_project
  setup_git_hooks
  
  display_next_steps
}

# Run main function with all arguments
main "$@"