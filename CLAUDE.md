# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Essential Commands
- `./scripts/setup.sh` - One-time project setup: installs dependencies, generates project, configures simulators
- `./scripts/build.sh` - Build the app (add `--device` for device builds, `--release` for Release config)
- `./scripts/test.sh` - Run unit tests (add `--ui` for UI tests, `--all` for both, `--release` for Release config)
- `./scripts/lint.sh` - Check code style with SwiftLint (add `--fix` for auto-fix, `--strict` for warnings as errors)
- `./scripts/format.sh` - Check code formatting with SwiftFormat (add `--fix` for auto-fix)
- `./scripts/preflight.sh` - Complete local CI check: fixes formatting, runs linting, builds, and tests
- `xcodegen` - Regenerate Xcode project from project.yml (required after adding/removing files or changing project structure)

### Simulator Management
- `./scripts/simulator.sh list` - Show available simulators
- `./scripts/simulator.sh config-tests "device-name"` - Configure simulator for unit tests
- `./scripts/simulator.sh config-ui-tests "device-name"` - Configure simulator for UI tests
- `./scripts/simulator.sh show-config` - Display current simulator configuration

## Architecture Overview

### Project Structure Pattern
This is a **Swift iOS project template** that uses:
- **XcodeGen**: Project files generated from `project.yml` configuration, not manually managed
- **In-Place Configuration**: Files contain `{{PLACEHOLDERS}}` that get replaced during setup
- **Dual Mode Setup**: Adopt existing Xcode projects OR generate minimal projects
- **Script Automation**: Comprehensive bash script ecosystem for all development tasks
- **Quality-First**: Built-in SwiftLint, SwiftFormat, and pre-commit hooks
- **Unified CI**: Same workflow runs on template repo and generated projects

### Core Components
- **`scripts/` Directory**: Contains all development automation scripts with helper functions in `_helpers.sh`
- **`project.yml`**: XcodeGen configuration with placeholders like `{{PROJECT_NAME}}`
- **`simulator.yml`**: Auto-generated simulator configuration for tests
- **`.github/workflows/ci.yml`**: Unified CI workflow that auto-configures if needed
- **Brewfile**: Manages all development tool dependencies (yq, jq, xcodegen, swiftlint, etc.)

### Setup Modes

**ADOPT Mode (Primary Workflow - Xcode-First)**
1. Create project in Xcode with your preferred template
2. Clone template repository into project directory
3. Run `./scripts/setup.sh --project-name YourApp`
4. Script detects existing .xcodeproj and configures tooling around it
5. Optional: Create directory structure with `--structure mvvm`

**GENERATE Mode (Secondary Workflow - Quick Start)**
1. Clone template repository
2. Run `./scripts/setup.sh --project-name YourApp --generate-minimal`
3. Script creates minimal Swift files and directory structure
4. Runs `xcodegen` to create `.xcodeproj` from configured `project.yml`
5. Configures simulators and installs pre-commit hooks

## Project Generation and Management

### Using This Template

**Primary Workflow (Xcode-First - Recommended)**
1. Create new project in Xcode using any template (SwiftUI App, UIKit, etc.)
2. Clone this template repository into the same directory
3. Run `./scripts/setup.sh --project-name YourApp`
4. Script adopts your Xcode project and adds tooling/automation
5. Optional: Use `--structure mvvm` to create directory structure

**Secondary Workflow (Quick Start)**
1. Clone this template repository
2. Run `./scripts/setup.sh --project-name YourApp --generate-minimal`
3. Script generates minimal project and configures everything
4. Result: Configured project with `YourApp/`, `YourAppTests/`, `YourAppUITests/`

### After Setup
- **Always run `xcodegen`** after modifying `project.yml` or adding/removing files
- Use scripts for all development tasks rather than Xcode's built-in build/test
- Directory structure is optional: use `--structure mvvm`, `--structure clean`, or `--structure none`
- In ADOPT mode, script works with your existing Xcode project structure
- In GENERATE mode, creates minimal UIKit project with configurable structure

## Configuration Files

### Critical Files (Pre-configured with Placeholders)
- **`project.yml`** - XcodeGen project definition with `{{PROJECT_NAME}}` placeholders
- **`simulator.yml`** - Auto-generated during setup with sensible defaults
- **`.swiftlint.yml`** - SwiftLint rules with `{{PROJECT_NAME}}` in paths
- **`.swiftformat`** - SwiftFormat configuration ready to use

### Development Dependencies
All tools installed via Brewfile: yq, jq, xcodegen, swiftlint, swiftformat, xcbeautify, gh

## Testing Strategy

### Test Target Structure
- **Unit Tests**: `{ProjectName}Tests/` - mirrors main app structure
- **UI Tests**: `{ProjectName}UITests/` - user interaction flows
- **Test Configuration**: Managed via `simulator.yml` for consistent device/OS selection
- **Coverage**: Enabled by default, viewable in Xcode Report Navigator

### Running Tests
- Unit tests use `simulators.tests` configuration from `simulator.yml`
- UI tests use `simulators.ui-tests` configuration from `simulator.yml`
- Scripts auto-detect available simulators and suggest alternatives if configured simulator not found

## Code Quality and Style

### Formatting and Linting
- **SwiftFormat**: 2-space indentation, 120 character line width, self insertion required
- **SwiftLint**: iOS development best practices, configurable via `.swiftlint.yml`
- **Pre-commit Hooks**: Automatically installed, run formatting and linting before commits

### Quality Workflow
1. `./scripts/format.sh --fix` - Fix formatting issues
2. `./scripts/lint.sh --fix` - Fix linting issues
3. `./scripts/build.sh` - Verify build
4. `./scripts/test.sh --all` - Run all tests
5. `./scripts/preflight.sh` - Complete quality check

## Common Development Tasks

### Adding New Features (in Generated Project)
1. Create files in appropriate directories (Models/, Views/, ViewModels/, Services/)
2. Add corresponding tests in `{ProjectName}Tests/`
3. Update `project.yml` if new groups/files need explicit configuration
4. Run `xcodegen` to regenerate project file
5. Run `./scripts/preflight.sh` before committing

### Template Development (this repository)
- Edit placeholder files directly (project.yml, .swiftlint.yml, etc.)
- Test with `./scripts/setup.sh --project-name TestApp --force`
- CI automatically tests template by running setup then preflight
- Same CI workflow works for both template and generated projects

### Before Every Commit
- Run `./scripts/preflight.sh` (does formatting, linting, building, testing)
- Review git diff for auto-fix changes
- Ensure all tests pass

### Debugging Issues
- **Build failures**: Clean build folder, run `xcodegen`, check `project.yml` syntax
- **Missing tools**: Run `brew bundle install` to install dependencies
- **Simulator issues**: Use `./scripts/simulator.sh list` to find available devices
- **Setup issues**: Check for `{{PLACEHOLDERS}}` that weren't replaced

## GitHub Integration

### CI/CD Strategy
- **Unified Workflow**: `.github/workflows/ci.yml` works for both template and generated projects
- **Auto-Configuration**: CI detects unconfigured state and runs setup automatically
- **Local Parity**: CI runs `./scripts/preflight.sh` - same as local development
- **No Duplication**: CI uses scripts instead of duplicating logic

### CI Workflow
1. Checkout code
2. Detect if project is configured (check for `{{PROJECT_NAME}}` in project.yml)
3. If unconfigured: run `./scripts/setup.sh --generate-minimal` with test parameters
4. Install dependencies via Brewfile
5. Generate Xcode project with xcodegen (or use existing in adopt mode)
6. Run `./scripts/preflight.sh` (format, lint, build, test)

### Template Testing
The template repository's CI automatically:
1. Detects it's unconfigured (sees `{{PLACEHOLDERS}}`)
2. Runs `setup.sh --generate-minimal` to create test project
3. Runs full preflight validation
4. Ensures template works before anyone uses it