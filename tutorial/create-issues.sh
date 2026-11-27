#!/usr/bin/env bash
# Creates the issues of one lesson of the tutorial: tutorial/create-issues.sh <lesson>
set -euo pipefail

readonly TEMPLATE_REPOSITORY="MeterianHQ/rossumworks-tutorial"
ISSUES_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/issues"
readonly ISSUES_DIRECTORY

stop_with_message() {
    echo "$1" >&2
    exit 1
}

show_lessons() {
    echo "Usage: tutorial/create-issues.sh <lesson>"
    echo "The lessons are:"
    find "${ISSUES_DIRECTORY}" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort
}

verify_lesson_exists() {
    if [[ ! "$1" =~ ^[a-z-]+$ || ! -d "${ISSUES_DIRECTORY}/$1" ]]; then
        show_lessons >&2
        exit 1
    fi
}

verify_programs() {
    local program
    for program in gh git; do
        command -v "${program}" > /dev/null || stop_with_message "The script needs ${program} on the PATH."
    done
    gh auth status > /dev/null 2>&1 || stop_with_message "Run gh auth login to log in."
}

find_repository() {
    local url
    url=$(git -C "${ISSUES_DIRECTORY}" remote get-url origin) \
        || stop_with_message "The clone has no remote with the name origin."
    if [[ ! "${url}" =~ github\.com[:/]([^/]+/[^/]+)$ ]]; then
        stop_with_message "The remote origin is not a GitHub repository: ${url}"
    fi
    echo "${BASH_REMATCH[1]%.git}"
}

verify_repository_is_not_template() {
    if [[ "${1,,}" == "${TEMPLATE_REPOSITORY,,}" ]]; then
        stop_with_message "This is the template repository. Make your own repository with \"Use this template\"."
    fi
}

read_title() {
    head -n 1 "$1"
}

read_body() {
    tail -n +3 "$1"
}

find_new_issue_files() {
    local lesson="$1"
    local existing_titles="$2"
    local file
    for file in "${ISSUES_DIRECTORY}/${lesson}"/*.md; do
        if ! grep --quiet --fixed-strings --line-regexp -- "$(read_title "${file}")" <<< "${existing_titles}"; then
            echo "${file}"
        fi
    done
}

confirm_creation() {
    local repository="$1"
    shift
    local file answer=""
    echo "The script creates these issues in ${repository}:"
    for file in "$@"; do
        echo "  $(read_title "${file}")"
    done
    read -r -p "Create the issues? [y/n] " answer || true
    [[ "${answer}" == "y" ]]
}

create_issues() {
    local repository="$1"
    shift
    local file
    for file in "$@"; do
        gh issue create --repo "${repository}" --title "$(read_title "${file}")" --body "$(read_body "${file}")"
    done
}

main() {
    local lesson="${1:-}"
    local repository existing_titles new_files
    verify_lesson_exists "${lesson}"
    verify_programs
    repository=$(find_repository)
    verify_repository_is_not_template "${repository}"
    existing_titles=$(gh issue list --repo "${repository}" --state all --limit 1000 --json title --jq '.[].title')
    mapfile -t new_files < <(find_new_issue_files "${lesson}" "${existing_titles}")
    if [[ ${#new_files[@]} -eq 0 ]]; then
        echo "All the issues of the lesson ${lesson} exist in ${repository}."
        return
    fi
    if ! confirm_creation "${repository}" "${new_files[@]}"; then
        echo "The script created no issue."
        return
    fi
    create_issues "${repository}" "${new_files[@]}"
    echo "Add the label factory to an issue to give it to the factory."
}

main "$@"
