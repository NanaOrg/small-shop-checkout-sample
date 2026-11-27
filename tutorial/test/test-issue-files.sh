#!/usr/bin/env bash
# Tests the format of the issue files: tutorial/test/test-issue-files.sh
set -euo pipefail

TUTORIAL_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TUTORIAL_DIRECTORY
readonly LESSONS=(first-fix block approval factory-change parallel)

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

verify_lesson_has_issues() {
    compgen -G "${TUTORIAL_DIRECTORY}/issues/$1/*.md" > /dev/null || fail "the lesson $1 has no issue"
}

verify_format() {
    [[ -n "$(sed -n 1p "$1")" ]] || fail "$1 has no title"
    [[ -z "$(sed -n 2p "$1")" ]] || fail "$1 has no empty line after the title"
    [[ -n "$(sed -n 3p "$1")" ]] || fail "$1 has no body"
}

verify_titles_are_unique() {
    local duplicates
    duplicates=$(for file in "${TUTORIAL_DIRECTORY}"/issues/*/*.md; do head -n 1 "${file}"; done | sort | uniq -d)
    [[ -z "${duplicates}" ]] || fail "more than one issue has the title: ${duplicates}"
}

for lesson in "${LESSONS[@]}"; do
    verify_lesson_has_issues "${lesson}"
done
for file in "${TUTORIAL_DIRECTORY}"/issues/*/*.md; do
    verify_format "${file}"
done
verify_titles_are_unique
echo "ok"
