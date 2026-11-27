#!/usr/bin/env bash
# Tests create-issues.sh with a fake gh: tutorial/test/test-create-issues.sh
set -euo pipefail

TUTORIAL_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE=$(mktemp -d)
readonly TUTORIAL_DIRECTORY WORKSPACE
trap 'rm -rf "${WORKSPACE}"' EXIT

# The fake keeps the created titles in a file, and fails on the create with the number FAIL_AT.
write_fake_gh() {
    mkdir -p "${WORKSPACE}/bin"
    cat > "${WORKSPACE}/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "${GH_CALLS}"
case "$1 $2" in
    "auth status") exit "${GH_AUTH_EXIT:-0}" ;;
    "issue list") cat "${GH_TITLES}" ;;
    "issue create")
        if [[ "$(grep -c '^issue create' "${GH_CALLS}")" == "${FAIL_AT:-none}" ]]; then
            exit 1
        fi
        echo "$6" >> "${GH_TITLES}"
        echo "https://github.com/$4/issues/1"
        ;;
esac
FAKE
    chmod +x "${WORKSPACE}/bin/gh"
}

prepare_clone() {
    rm -rf "${WORKSPACE}/clone"
    mkdir -p "${WORKSPACE}/clone/tutorial/issues/sample"
    cp "${TUTORIAL_DIRECTORY}/create-issues.sh" "${WORKSPACE}/clone/tutorial/"
    printf 'First title\n\nFirst body\n' > "${WORKSPACE}/clone/tutorial/issues/sample/first.md"
    printf 'Second title\n\nSecond body\n' > "${WORKSPACE}/clone/tutorial/issues/sample/second.md"
    git -C "${WORKSPACE}/clone" init --quiet
    git -C "${WORKSPACE}/clone" remote add origin "$1"
    export GH_CALLS="${WORKSPACE}/calls" GH_TITLES="${WORKSPACE}/titles"
    : > "${GH_CALLS}"
    : > "${GH_TITLES}"
}

# Runs the script with the answer $1 and the other arguments. Sets output and exit_code.
run_script() {
    local answer="$1"
    shift
    exit_code=0
    output=$(PATH="${WORKSPACE}/bin:${PATH}" "${WORKSPACE}/clone/tutorial/create-issues.sh" "$@" \
        <<< "${answer}" 2>&1) || exit_code=$?
}

count_created() {
    wc -l < "${GH_TITLES}" | tr -d ' '
}

assert_equals() {
    if [[ "$1" != "$2" ]]; then
        echo "FAIL: ${FUNCNAME[1]}: expected [$1], got [$2]" >&2
        echo "${output}" >&2
        exit 1
    fi
}

assert_output_has() {
    if [[ "${output}" != *"$1"* ]]; then
        echo "FAIL: ${FUNCNAME[1]}: the output does not have [$1]" >&2
        echo "${output}" >&2
        exit 1
    fi
}

test_first_run_creates_all_issues() {
    prepare_clone git@github.com:someone/sample.git
    run_script y sample
    assert_equals 0 "${exit_code}"
    assert_equals 2 "$(count_created)"
    assert_equals "issue create --repo someone/sample --title First title --body First body" \
        "$(grep '^issue create' "${GH_CALLS}" | head -n 1)"
}

test_second_run_creates_nothing() {
    prepare_clone https://github.com/someone/sample.git
    run_script y sample
    run_script y sample
    assert_equals 0 "${exit_code}"
    assert_equals 2 "$(count_created)"
    assert_output_has "All the issues of the lesson sample exist"
}

test_similar_title_does_not_count() {
    prepare_clone https://github.com/someone/sample
    echo "First title again" > "${GH_TITLES}"
    run_script y sample
    assert_equals 3 "$(count_created)"
}

test_refused_confirmation_creates_nothing() {
    prepare_clone https://github.com/someone/sample
    run_script n sample
    assert_equals 0 "${exit_code}"
    assert_equals 0 "$(count_created)"
}

test_template_repository_is_refused() {
    prepare_clone git@github.com:MeterianHQ/rossumworks-tutorial.git
    run_script y sample
    assert_equals 1 "${exit_code}"
    assert_equals 0 "$(count_created)"
    assert_output_has "template repository"
}

test_other_host_is_refused() {
    prepare_clone git@example.com:someone/sample.git
    run_script y sample
    assert_equals 1 "${exit_code}"
    assert_equals 0 "$(count_created)"
}

test_unknown_lesson_shows_lessons() {
    prepare_clone https://github.com/someone/sample
    run_script y other
    assert_equals 1 "${exit_code}"
    assert_output_has "  sample"
}

test_no_lesson_shows_lessons() {
    prepare_clone https://github.com/someone/sample
    run_script y
    assert_equals 1 "${exit_code}"
    assert_output_has "  sample"
}

test_no_login_stops() {
    prepare_clone https://github.com/someone/sample
    GH_AUTH_EXIT=1 run_script y sample
    assert_equals 1 "${exit_code}"
    assert_equals 0 "$(count_created)"
    assert_output_has "gh auth login"
}

test_run_after_failure_creates_missing_issue() {
    prepare_clone https://github.com/someone/sample
    FAIL_AT=2 run_script y sample
    assert_equals 1 "${exit_code}"
    assert_equals 1 "$(count_created)"
    run_script y sample
    assert_equals 0 "${exit_code}"
    assert_equals 2 "$(count_created)"
}

write_fake_gh
for test_name in $(compgen -A function test_); do
    "${test_name}"
    echo "ok ${test_name}"
done
