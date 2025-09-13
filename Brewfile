# Brewfile for SwiftProjectTemplate
# Usage:
#   brew bundle install --file=./Brewfile
#   brew bundle cleanup --file=./Brewfile   # show what would be removed
#   brew bundle check --file=./Brewfile     # check if all dependencies are installed

# --- Core Dev Utilities -----------------------------------------------
brew "git"
brew "make"
# JSON processing for Xcode simulator APIs
brew "jq"
# YAML processing and manipulation
brew "yq"
# GitHub CLI for CI management
brew "gh"

# --- iOS / Swift Tooling ----------------------------------------------
# Project generator from project.yml
brew "xcodegen"
# Linting
brew "swiftlint"
# Formatting
brew "swiftformat"
# Optional: pretty Xcode build logs in CI / local
brew "xcbeautify"

# --- Notes -------------------------------------------------------------
# Homebrew doesn't pin exact versions in Brewfiles by design.
# All formulas are available in homebrew-core (no custom taps needed).