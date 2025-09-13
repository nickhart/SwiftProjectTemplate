# SwiftProjectTemplate - Implementation Plan

## Overview
A comprehensive iOS project template repository that includes all common infrastructure, tooling, and automation needed for Swift iOS development. This template eliminates the need to recreate boilerplate configuration for every new iOS project.

## Goals
- **Zero Setup Time**: Clone and run `./scripts/setup.sh` to get a fully configured iOS project
- **Consistency**: Standardized tooling, formatting, and project structure across all iOS projects
- **Automation**: Smart scripts that use `yq` to extract project info and auto-configure simulators
- **Flexibility**: Support both interactive and CLI-driven setup for different workflows
- **Future-Proof**: Designed to easily extend for macOS, watchOS, and tvOS targets

## Repository Structure

```
SwiftProjectTemplate/
├── .github/
│   ├── workflows/
│   │   └── pr-validation.yml           # PR checks: lint, format, test, build
│   └── pull_request_template.md        # Standard PR template
├── .vscode/
│   ├── extensions.json                 # Recommended extensions (Swift, YAML, Markdown)
│   └── settings.json                   # Format on save, rulers, file associations
├── scripts/
│   ├── _helpers.sh                     # Shared helper functions
│   ├── setup.sh                        # ✨ Enhanced interactive/CLI setup
│   ├── xcodegen-config.sh             # ✨ XcodeGen project.yml generator
│   ├── simulator.sh                   # ✨ Enhanced simulator management with yq
│   ├── build.sh                       # Build wrapper with device/simulator support
│   ├── test.sh                        # Test runner with simulator selection
│   ├── lint.sh                        # SwiftLint checking and fixing
│   ├── format.sh                      # SwiftFormat checking and fixing
│   ├── pre-commit.sh                  # Git pre-commit hook
│   ├── preflight.sh                   # Full local CI: format, lint, test
│   └── ci.sh                          # CI-specific build and test
├── templates/
│   ├── project.yml.template           # Parameterized XcodeGen config
│   ├── README.md.template             # README with badges and project info
│   ├── .gitignore.template            # iOS-specific gitignore
│   ├── .swiftformat.template          # SwiftFormat configuration
│   ├── .swiftlint.yml.template        # SwiftLint rules and exclusions
│   ├── simulator.yml.template         # Simulator configuration template
│   ├── CLAUDE.md.template             # Claude Code guidance template
│   └── TODO.md.template               # Project TODO skeleton
├── Brewfile                           # Dependencies: yq, jq, xcodegen, etc.
├── .swift-version                     # Default Swift 5.10
├── .markdownlint.json                 # Markdown linting rules
├── LICENSE                            # MIT License (already exists)
├── TODO.md                            # Future enhancements tracking
└── README.md                          # Template usage documentation
```

## Key Features

### 1. Smart Setup Script (`setup.sh`)

**Hybrid Interactive/CLI Mode:**
- CLI arguments populate variables
- Interactive prompts only ask for missing information
- Validates conflicting options with clear error messages

**CLI Arguments:**
```bash
./scripts/setup.sh [OPTIONS]

OPTIONS:
  --project-name <name>              Project name (e.g., "FooApp")
  --deployment-target <version>      iOS deployment target (default: 18.0)
  --swift-version <version>          Swift version (default: 5.10)
  --public                          Public project (includes LICENSE in README)
  --private                         Private project (default)
  --force                           Overwrite existing files
  --help                            Show this help

EXAMPLES:
  ./scripts/setup.sh                                    # Interactive mode
  ./scripts/setup.sh --project-name "MyApp"             # Partial CLI + interactive
  ./scripts/setup.sh --project-name "MyApp" --public    # Mostly CLI + minimal prompts
```

**Workflow:**
1. Parse CLI arguments and validate for conflicts
2. Prompt interactively for missing required information
3. Install Homebrew dependencies via `brew bundle`
4. Generate all configuration files from templates
5. Call `xcodegen-config.sh` to create project structure
6. Set up git pre-commit hooks
7. Display next steps and available commands

### 2. XcodeGen Configuration Generator (`xcodegen-config.sh`)

**Features:**
- Auto-generates comprehensive `project.yml` from template
- Creates MVVM folder structure with `.gitkeep` files
- Exits early if `project.yml` exists (unless `--force`)
- Uses `yq` for YAML manipulation and validation

**Generated Structure:**
```
ProjectName/
├── Models/
│   └── .gitkeep
├── Views/
│   └── .gitkeep
├── ViewModels/
│   └── .gitkeep
├── Services/
│   └── .gitkeep
├── Extensions/
│   └── .gitkeep
└── Helpers/
    └── .gitkeep
ProjectNameTests/
├── Models/
├── Views/
├── ViewModels/
└── Services/
ProjectNameUITests/
└── .gitkeep
```

### 3. Enhanced Simulator Management (`simulator.sh`)

**New Capabilities:**
```bash
# Current functionality (preserved)
./scripts/simulator.sh list --family iPhone --os 18.1
./scripts/simulator.sh create --device "iPhone 15 Pro" --os 18.1 --name "Test Device"

# ✨ New configuration features
./scripts/simulator.sh --config-tests "iPhone 16 Pro Max"     # Auto-configure for tests
./scripts/simulator.sh --config-ui-tests "iPad Air 11-inch"   # Auto-configure for UI tests
```

**Smart Auto-Detection:**
- Detects optimal iOS version based on deployment target from `project.yml`
- Selects appropriate architecture (arm64 for Apple Silicon, x86_64 for Intel)
- Writes configuration to `simulator.yml` using `yq`

**simulator.yml Structure:**
```yaml
simulators:
  tests:
    device: "iPhone 16 Pro Max"
    os: "18.1"
    arch: "arm64"
  ui-tests:
    device: "iPad Air 11-inch"
    os: "17.0"
    arch: "arm64"
```

### 4. Comprehensive Tooling Integration

**Brewfile Dependencies:**
- `yq` - YAML processing and manipulation
- `jq` - JSON processing for Xcode simulator APIs
- `xcodegen` - Project file generation
- `swiftlint` - Code linting
- `swiftformat` - Code formatting
- `xcbeautify` - Pretty Xcode build output
- `gh` - GitHub CLI for CI/CD

**VSCode Integration:**
- Swift language support
- Markdown linting with auto-fix
- YAML formatting and validation
- Format on save for all file types
- Custom file associations for Swift tooling files
- Optimized search/exclude patterns

### 5. GitHub Workflow Automation

**PR Validation (`pr-validation.yml`):**
```yaml
# Triggers: Pull requests to main/develop
# Jobs:
#   - SwiftLint validation
#   - SwiftFormat checking
#   - Unit test execution
#   - UI test execution (if applicable)
#   - Multi-simulator build validation
#   - Test coverage reporting
```

## Implementation Phases

### Phase 1: Foundation ✅ (Current)
- [x] Repository structure created
- [x] Basic files (README, LICENSE, .gitignore) in place
- [ ] Create implementation plan (this document)

### Phase 2: Core Infrastructure
- [ ] Create `Brewfile` with all required dependencies
- [ ] Set up basic script structure with `_helpers.sh`
- [ ] Create VSCode configuration (`.vscode/`)
- [ ] Add `.swift-version` and `.markdownlint.json`

### Phase 3: Template System
- [ ] Create `templates/` directory with all template files
- [ ] Implement template variable substitution system
- [ ] Create comprehensive `project.yml.template`
- [ ] Design README, CLAUDE.md, and TODO templates

### Phase 4: Enhanced Setup Script
- [ ] Implement hybrid interactive/CLI argument parsing
- [ ] Add input validation and conflict detection
- [ ] Create template file generation logic
- [ ] Integrate with brew bundle installation

### Phase 5: XcodeGen Integration
- [ ] Implement `xcodegen-config.sh` script
- [ ] Create MVVM folder structure generation
- [ ] Add `yq` integration for YAML manipulation
- [ ] Test project generation workflow

### Phase 6: Enhanced Simulator Management
- [ ] Extend `simulator.sh` with configuration features
- [ ] Implement auto-detection of optimal OS/architecture
- [ ] Create `simulator.yml` integration with `yq`
- [ ] Add smart defaults based on `project.yml`

### Phase 7: GitHub Integration
- [ ] Create PR validation workflow
- [ ] Design pull request template
- [ ] Test CI/CD pipeline
- [ ] Document GitHub integration setup

### Phase 8: Testing & Polish
- [ ] End-to-end testing with various project configurations
- [ ] Error handling and user experience refinement
- [ ] Performance optimization for large projects
- [ ] Comprehensive documentation and examples

## Future Enhancements (Post-MVP)

### Code Generation Tools
- **Model/View/ViewModel Generator**: Interactive tool to create skeleton Swift files
- **API Client Generator**: Generate networking code from OpenAPI specs
- **Core Data Model Generator**: Create Core Data models from simple schemas

### Platform Expansion
- **macOS Support**: Extend templates for macOS app development
- **watchOS/tvOS**: Additional platform templates and tooling
- **Multi-Platform**: Shared code templates for iOS/macOS projects

### Advanced Automation
- **Release Automation**: GitHub workflows for versioning and App Store Connect
- **Dependency Management**: Automated dependency updates with testing
- **Performance Monitoring**: Integration with performance testing tools

### Developer Experience
- **Project Health Dashboard**: Script to analyze project health metrics
- **Migration Tools**: Helpers for upgrading between iOS/Swift versions
- **Team Onboarding**: Automated setup for new team members

## Success Metrics

### Primary Goals
1. **Setup Time**: Reduce new project setup from 2+ hours to <5 minutes
2. **Consistency**: 100% standardization of tooling across all iOS projects
3. **Automation**: Zero manual configuration for common development tasks

### Quality Metrics
1. **Test Coverage**: All scripts have comprehensive test coverage
2. **Error Handling**: Graceful failure with actionable error messages
3. **Documentation**: Complete usage examples and troubleshooting guides

### Adoption Metrics
1. **Template Usage**: Track GitHub template repository usage
2. **Community Feedback**: Monitor issues and feature requests
3. **Maintenance Overhead**: Minimize ongoing template maintenance

---

## Getting Started

Once implementation is complete, using this template will be as simple as:

1. **Create New Repository**: Use this as a GitHub template repository
2. **Clone and Setup**: `git clone <your-repo> && cd <your-repo>`
3. **Run Setup**: `./scripts/setup.sh --project-name "MyAwesomeApp"`
4. **Start Developing**: Open in Xcode and start building!

The template handles everything else: project generation, simulator configuration, CI/CD setup, and development tooling integration.
