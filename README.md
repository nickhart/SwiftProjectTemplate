# SwiftProjectTemplate

A comprehensive iOS project template repository that includes all common infrastructure, tooling, and automation needed for professional Swift iOS development. This template eliminates the need to recreate boilerplate configuration for every new iOS project.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![iOS 18.0+](https://img.shields.io/badge/iOS-18.0%2B-blue.svg)](https://developer.apple.com/ios/)

## Features

🚀 **Zero Setup Time**: Clone and run `./scripts/setup.sh` to get a fully configured iOS project  
⚙️ **Smart Configuration**: Uses `yq` to extract project info and auto-configure simulators  
🎨 **Code Quality**: Integrated SwiftLint, SwiftFormat, and pre-commit hooks  
🏗️ **XcodeGen Integration**: Project files generated from `project.yml` configuration  
🤖 **CI/CD Ready**: GitHub Actions workflow for automated testing and validation  
📱 **Simulator Management**: Advanced simulator configuration with auto-detection  
🔧 **Developer Tools**: Comprehensive script ecosystem for building, testing, and deployment

## Quick Start

### 1. Use this Template

Click "Use this template" on GitHub or:

```bash
# Option 1: Use GitHub CLI
gh repo create MyAwesomeApp --template nickhart/SwiftProjectTemplate

# Option 2: Clone and rename
git clone https://github.com/nickhart/SwiftProjectTemplate.git MyAwesomeApp
cd MyAwesomeApp
rm -rf .git && git init
```

### 2. Run Setup

```bash
# Interactive mode
./scripts/setup.sh

# Or CLI mode
./scripts/setup.sh --project-name "MyAwesomeApp" --public
```

### 3. Configure Simulators

```bash
# List available simulators
./scripts/simulator.sh list

# Configure simulators for testing (choose available device)
./scripts/simulator.sh config-tests "iPhone 16 Pro"
./scripts/simulator.sh config-ui-tests "iPad Air 11-inch"
```

### 4. Start Developing

```bash
# Open in Xcode
open MyAwesomeApp.xcodeproj

# Or build from command line
./scripts/build.sh
```

## What You Get

### 📁 Project Structure
```
MyAwesomeApp/
├── MyAwesomeApp/
│   ├── Models/              # Data models and Core Data entities
│   ├── Views/               # SwiftUI views and UI components  
│   ├── ViewModels/          # Business logic and view state
│   ├── Services/            # Network, persistence, business services
│   ├── Extensions/          # Swift extensions and utilities
│   └── Helpers/             # Helper functions and utilities
├── MyAwesomeAppTests/       # Unit tests (mirrors main structure)
├── MyAwesomeAppUITests/     # UI tests
└── scripts/                 # Development automation scripts
```

### 🛠️ Development Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | One-time project setup and dependency installation |
| `build.sh` | Build for simulator or device with various configurations |
| `test.sh` | Run unit tests, UI tests, or both with smart simulator selection |
| `lint.sh` | SwiftLint checking and auto-fixing |
| `format.sh` | SwiftFormat checking and auto-fixing |
| `simulator.sh` | **Enhanced** simulator management with auto-configuration |
| `preflight.sh` | Complete local CI check before committing |
| `ci.sh` | Optimized script for CI/CD environments |

### ⚡ Enhanced Features

#### Smart Simulator Management
```bash
# Auto-configure simulators based on your project
./scripts/simulator.sh --config-tests "iPhone 16 Pro Max"
./scripts/simulator.sh --config-ui-tests "iPad Air 11-inch"

# Show optimal OS version for your deployment target
./scripts/simulator.sh optimal-os
```

#### Hybrid Setup Script
```bash
# Interactive mode - prompts for missing info
./scripts/setup.sh --project-name "MyApp"

# Full CLI mode
./scripts/setup.sh --project-name "MyApp" --deployment-target "17.0" --public --force
```

#### Intelligent Configuration
- **Auto-detects** optimal iOS version from deployment target
- **Auto-detects** Mac architecture (Apple Silicon vs Intel)
- **Validates** device names against available simulators
- **Syncs** simulator.yml with project.yml using `yq`

### 🔧 Configuration Files

- **`.swiftlint.yml`** - Comprehensive linting rules for iOS development
- **`.swiftformat`** - Consistent code formatting configuration  
- **`project.yml`** - XcodeGen project definition (no more .pbxproj conflicts!)
- **`simulator.yml`** - Simulator configuration for tests and UI tests
- **`Brewfile`** - All development dependencies (yq, jq, xcodegen, etc.)
- **`.github/workflows/`** - CI/CD automation with GitHub Actions

### 🎯 Code Quality

- **Pre-commit hooks** automatically run formatting and linting
- **GitHub Actions** validate every pull request
- **Code coverage** collection and reporting
- **Comprehensive error handling** with helpful suggestions

## Advanced Usage

### CLI Arguments

The setup script supports both interactive and CLI modes:

```bash
./scripts/setup.sh [OPTIONS]

Options:
  --project-name <name>         Project name (e.g., "FooApp")
  --deployment-target <version> iOS deployment target (default: 18.0)
  --swift-version <version>     Swift version (default: 5.10)
  --public                     Public project (includes LICENSE in README)
  --private                    Private project (default)
  --force                      Overwrite existing files
  --help                       Show help
```

### Simulator Configuration

Configure simulators that match your project needs:

```bash
# Configure test simulator
./scripts/simulator.sh --config-tests "iPhone 15 Pro" --os 17.5

# Configure UI test simulator  
./scripts/simulator.sh --config-ui-tests "iPad Pro 12.9-inch" --force

# Show current configuration
./scripts/simulator.sh show-config
```

### Development Workflow

```bash
# Daily development
./scripts/build.sh                    # Build project
./scripts/test.sh --all               # Run all tests  
./scripts/lint.sh --fix               # Fix linting issues

# Before committing
./scripts/preflight.sh                # Full quality check

# CI/CD
./scripts/ci.sh                       # Optimized for CI environments
```

## Requirements

- **macOS** with Xcode 15.0+
- **Homebrew** for dependency management
- **Git** for version control

The setup script will install all other dependencies automatically.

## Dependencies

Installed automatically via Brewfile:

- **yq** - YAML processing and manipulation
- **jq** - JSON processing for Xcode APIs  
- **xcodegen** - Project file generation
- **swiftlint** - Code linting
- **swiftformat** - Code formatting
- **xcbeautify** - Pretty build output
- **gh** - GitHub CLI

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `./scripts/preflight.sh` to ensure quality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Template Philosophy

This template embodies these principles:

- **Zero Configuration**: Works out of the box with sensible defaults
- **Intelligent Automation**: Scripts that understand your project structure
- **Quality First**: Built-in code quality enforcement
- **Developer Experience**: Optimized for daily development workflows
- **CI/CD Ready**: Seamless integration with modern development practices

## Roadmap

See [TODO.md](TODO.md) for planned enhancements including:

- 🎯 **Code Generation Tools**: Skeleton Model/View/ViewModel generators
- 🍎 **Platform Expansion**: macOS, watchOS, tvOS support
- 🏪 **Template Marketplace**: Community-contributed templates
- 📊 **Project Analytics**: Health dashboards and metrics

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the need for consistent iOS project setup
- Built with modern iOS development best practices
- Designed for teams and individual developers alike

---

**Ready to build something amazing?** 🚀

[Use this template](https://github.com/nickhart/SwiftProjectTemplate/generate) and start your next iOS project in minutes, not hours!