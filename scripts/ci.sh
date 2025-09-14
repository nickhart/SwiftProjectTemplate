#!/usr/bin/env bash
set -euo pipefail

# CI Utility script for SwiftProjectTemplate projects
# GitHub CLI wrapper for common CI operations

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
SHOW_ALL_RUNS=false
LIMIT=10

show_help() {
  cat <<EOF
CI Utility Script

GitHub CLI wrapper for common CI operations and workflow management.
Use this script to easily interact with GitHub Actions CI runs.

USAGE:
  $0 <command> [options]

COMMANDS:
  status                   Show status of latest CI run
  list                     List recent CI runs (default: 10)
  logs [run-id]            Show logs for specific run (latest if no ID)
  rerun [run-id]           Rerun a specific workflow run (latest if no ID)
  watch                    Watch the latest run in real-time
  workflow <name>          Trigger a specific workflow
  runs                     Open GitHub Actions page in browser

OPTIONS (for list command):
  --all                    Show all runs (not just latest workflow)
  --limit N                Show N runs (default: 10)
  --help                   Show this help message

EXAMPLES:
  $0 status                # Show latest CI run status
  $0 list                  # List 10 most recent runs
  $0 list --limit 20       # List 20 most recent runs
  $0 logs                  # Show logs for latest run
  $0 logs 1234567890       # Show logs for specific run ID
  $0 rerun                 # Rerun latest run
  $0 watch                 # Watch latest run progress
  $0 workflow "CI"         # Trigger CI workflow
  $0 runs                  # Open Actions page in browser

PREREQUISITES:
  • GitHub CLI (gh) must be installed and authenticated
  • Repository must be connected to GitHub
  • GitHub Actions must be enabled for the repository

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --all)
        SHOW_ALL_RUNS=true
        shift
        ;;
      --limit)
        LIMIT="$2"
        shift 2
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
        # This is a command, stop parsing
        break
        ;;
    esac
  done
}

check_prerequisites() {
  if ! check_required_tools gh; then
    log_error "GitHub CLI (gh) is required but not installed"
    log_info "Install with: brew install gh"
    log_info "Then authenticate with: gh auth login"
    exit 1
  fi
  
  # Check if authenticated
  if ! gh auth status &>/dev/null; then
    log_error "GitHub CLI is not authenticated"
    log_info "Run: gh auth login"
    exit 1
  fi
  
  # Check if in a git repo with remote
  if ! git remote get-url origin &>/dev/null; then
    log_error "No git remote 'origin' found"
    log_info "This command requires a GitHub repository"
    exit 1
  fi
}

show_status() {
  log_info "Latest CI Run Status"
  echo
  
  local latest_run
  latest_run=$(gh run list --limit 1 --json databaseId,status,conclusion,workflowName,headBranch,createdAt,url --jq '.[0]')
  
  if [[ -z "$latest_run" || "$latest_run" == "null" ]]; then
    log_warning "No CI runs found"
    return 0
  fi
  
  local status conclusion workflow branch created_at url
  status=$(echo "$latest_run" | jq -r '.status')
  conclusion=$(echo "$latest_run" | jq -r '.conclusion // "running"')
  workflow=$(echo "$latest_run" | jq -r '.workflowName')
  branch=$(echo "$latest_run" | jq -r '.headBranch')
  created_at=$(echo "$latest_run" | jq -r '.createdAt')
  url=$(echo "$latest_run" | jq -r '.url')
  
  echo "  • Workflow: $workflow"
  echo "  • Branch: $branch"
  echo "  • Status: $status"
  echo "  • Conclusion: $conclusion"
  echo "  • Created: $created_at"
  echo "  • URL: $url"
  echo
  
  if [[ "$status" == "in_progress" ]]; then
    log_info "Use '$0 watch' to follow progress in real-time"
  elif [[ "$conclusion" == "failure" ]]; then
    log_info "Use '$0 logs' to view error details"
  fi
}

list_runs() {
  log_info "Recent CI Runs"
  echo
  
  local list_args=(--limit "$LIMIT")
  if [[ "$SHOW_ALL_RUNS" == "true" ]]; then
    gh run list "${list_args[@]}"
  else
    gh run list "${list_args[@]}" --workflow "$(get_primary_workflow)"
  fi
}

get_primary_workflow() {
  # Try to find the most common workflow name
  local primary_workflow
  primary_workflow=$(gh run list --limit 50 --json workflowName --jq '.[] | .workflowName' | sort | uniq -c | sort -nr | head -1 | awk '{print $2}')
  echo "${primary_workflow:-CI}"
}

show_logs() {
  local run_id="$1"
  
  if [[ -z "$run_id" ]]; then
    log_info "Getting logs for latest run..."
    run_id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
    
    if [[ -z "$run_id" || "$run_id" == "null" ]]; then
      log_error "No runs found"
      exit 1
    fi
  fi
  
  log_info "Showing logs for run ID: $run_id"
  echo
  gh run view "$run_id" --log
}

rerun_workflow() {
  local run_id="$1"
  
  if [[ -z "$run_id" ]]; then
    log_info "Getting latest run for rerun..."
    run_id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
    
    if [[ -z "$run_id" || "$run_id" == "null" ]]; then
      log_error "No runs found"
      exit 1
    fi
  fi
  
  log_info "Rerunning workflow run: $run_id"
  
  if gh run rerun "$run_id"; then
    log_success "Workflow rerun triggered successfully"
    log_info "Use '$0 watch' to follow progress"
  else
    log_error "Failed to rerun workflow"
    exit 1
  fi
}

watch_run() {
  log_info "Watching latest CI run..."
  
  local run_id
  run_id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
  
  if [[ -z "$run_id" || "$run_id" == "null" ]]; then
    log_error "No runs found to watch"
    exit 1
  fi
  
  gh run watch "$run_id"
}

trigger_workflow() {
  local workflow_name="$1"
  
  if [[ -z "$workflow_name" ]]; then
    log_error "Workflow name is required"
    log_info "Use: $0 workflow <workflow-name>"
    exit 1
  fi
  
  log_info "Triggering workflow: $workflow_name"
  
  if gh workflow run "$workflow_name"; then
    log_success "Workflow triggered successfully"
    sleep 2  # Give GitHub a moment to process
    log_info "Use '$0 status' to check progress"
  else
    log_error "Failed to trigger workflow"
    log_info "Available workflows:"
    gh workflow list
    exit 1
  fi
}

open_runs() {
  log_info "Opening GitHub Actions page..."
  gh run list --web
}

# Main execution
main() {
  parse_arguments "$@"
  
  # Skip the parsed arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --all|--limit)
        shift
        [[ "$1" =~ ^--.*$ ]] || shift  # Skip value if it's not another option
        ;;
      --*)
        shift
        ;;
      *)
        break
        ;;
    esac
  done
  
  local command="${1:-status}"
  shift || true
  
  check_prerequisites
  
  case "$command" in
    status)
      show_status
      ;;
    list)
      list_runs
      ;;
    logs)
      show_logs "${1:-}"
      ;;
    rerun)
      rerun_workflow "${1:-}"
      ;;
    watch)
      watch_run
      ;;
    workflow)
      trigger_workflow "${1:-}"
      ;;
    runs)
      open_runs
      ;;
    *)
      log_error "Unknown command: $command"
      echo "Use '$0 --help' for usage information"
      exit 1
      ;;
  esac
}

# Run main function with all arguments
main "$@"