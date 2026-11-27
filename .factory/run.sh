#!/usr/bin/env bash
# Starts the worker of the factory with the latest release of rossumworks.
# It prefers the native program of this machine. Else it uses the jar, which needs a JDK 21 or later.
# The arguments go to the run command, for example: .factory/run.sh --config <file>
set -euo pipefail

readonly RELEASES_PAGE="https://github.com/MeterianHQ/rossumworks/releases"
readonly LATEST_RELEASE_API="https://api.github.com/repos/MeterianHQ/rossumworks/releases/latest"
readonly JAR_CACHE_DIRECTORY="${HOME}/.rossumworks/jars"
readonly NATIVE_CACHE_DIRECTORY="${HOME}/.rossumworks/native"
readonly CHECKSUM_FAILURE=2

# The worker uses the same token: FACTORY_GITHUB_TOKEN, else the token of gh.
read_token() {
    if [[ -n "${FACTORY_GITHUB_TOKEN:-}" ]]; then
        echo "${FACTORY_GITHUB_TOKEN}"
    elif command -v gh > /dev/null; then
        gh auth token 2> /dev/null || true
    fi
}

call_github() {
    local accept="$1"
    local url="$2"
    shift 2
    local options=(--silent --show-error --fail --location --header "Accept: ${accept}")
    if [[ -n "${token}" ]]; then
        options+=(--header "Authorization: Bearer ${token}")
    fi
    curl "${options[@]}" "$@" "${url}"
}

# Prints the platform name of the native programs, for example linux-x64. A machine without a program gives nothing.
find_platform() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        return 1
    fi
    case "$(uname -m)" in
        x86_64) echo "linux-x64" ;;
        aarch64 | arm64) echo "linux-arm64" ;;
        *) return 1 ;;
    esac
}

# Prints the name and the API URL of the first asset whose name matches the pattern, on one line.
find_asset() {
    local release="$1"
    local pattern="$2"
    jq --raw-output --exit-status --arg pattern "${pattern}" \
        '.assets[] | select(.name | test($pattern)) | "\(.name) \(.url)"' <<< "${release}" \
        | head -n 1 | grep .
}

# Downloads an asset to a file. A failed download leaves no file.
download_asset() {
    local url="$1"
    local file="$2"
    call_github "application/octet-stream" "${url}" --output "${file}" || {
        rm -f "${file}"
        return 1
    }
}

download_latest_jar() {
    local release="$1"
    local name url
    read -r name url < <(find_asset "${release}" '^rossumworks-[0-9.]+\.jar$') || return 1
    local jar="${JAR_CACHE_DIRECTORY}/${name}"
    if [[ ! -f "${jar}" ]]; then
        echo "Download of ${name}" >&2
        download_asset "${url}" "${jar}.partial" || return 1
        mv "${jar}.partial" "${jar}"
    fi
    echo "${jar}"
}

# Compares the SHA-256 of the file with the first word of the checksum file.
verify_checksum() {
    local file="$1"
    local checksum_file="$2"
    local expected actual
    expected=$(cut -d ' ' -f 1 "${checksum_file}")
    actual=$(compute_sha256 "${file}" | cut -d ' ' -f 1)
    [[ -n "${expected}" && "${expected}" == "${actual}" ]]
}

# macOS 13 and older have shasum, but not sha256sum.
compute_sha256() {
    local file="$1"
    if command -v sha256sum > /dev/null; then
        sha256sum "${file}"
    else
        shasum -a 256 "${file}"
    fi
}

# Only a program with a correct SHA-256 goes into the cache. A wrong SHA-256 gives the code CHECKSUM_FAILURE.
download_latest_native_program() {
    local release="$1"
    local platform="$2"
    local name url checksum_name checksum_url
    read -r name url < <(find_asset "${release}" "^rossumworks-[0-9.]+-${platform}\$") || return 1
    local program="${NATIVE_CACHE_DIRECTORY}/${name}"
    if [[ -f "${program}" ]]; then
        echo "${program}"
        return 0
    fi
    read -r checksum_name checksum_url < <(find_asset "${release}" "^${name//./\\.}\\.sha256\$") || {
        echo "The release has no checksum for ${name}. The script does not use this program." >&2
        return 1
    }
    echo "Download of ${name}" >&2
    download_asset "${url}" "${program}.partial" || return 1
    download_asset "${checksum_url}" "${program}.partial.sha256" || {
        rm -f "${program}.partial"
        return 1
    }
    if ! verify_checksum "${program}.partial" "${program}.partial.sha256"; then
        rm -f "${program}.partial" "${program}.partial.sha256"
        echo "The SHA-256 of ${name} is not the SHA-256 of ${checksum_name}. Download the program again." >&2
        return "${CHECKSUM_FAILURE}"
    fi
    rm -f "${program}.partial.sha256"
    chmod +x "${program}.partial"
    mv "${program}.partial" "${program}"
    echo "${program}"
}

# The commands have only the options that the tools of Linux and of macOS share.
find_newest_cached_file() {
    local directory="$1"
    local pattern="$2"
    find "${directory}" -maxdepth 1 | sed 's#^.*/##' | grep -E -x "${pattern}" \
        | sort --version-sort | tail -n 1 | sed "s#^#${directory}/#" | grep .
}

# A native program needs glibc 2.34 or later. On an older Linux, it does not start, and the script uses the jar.
verify_native_program_starts() {
    local program="$1"
    if "${program}" --version > /dev/null 2>&1; then
        return 0
    fi
    echo "The native program ${program} does not start on this machine. The script uses the jar." >&2
    return 1
}

# Prints the kind and the path of the program, on one line: "native <path>" or "jar <path>".
select_program() {
    local release program status
    if release=$(call_github "application/vnd.github+json" "${LATEST_RELEASE_API}"); then
        if [[ -n "${platform}" ]]; then
            status=0
            program=$(download_latest_native_program "${release}" "${platform}") || status=$?
            if [[ "${status}" -eq "${CHECKSUM_FAILURE}" ]]; then
                return "${CHECKSUM_FAILURE}"
            fi
            if [[ "${status}" -eq 0 ]] && verify_native_program_starts "${program}"; then
                echo "native ${program}"
                return 0
            fi
        fi
        if program=$(download_latest_jar "${release}"); then
            echo "jar ${program}"
            return 0
        fi
    fi
    echo "Cannot download the latest release. The script uses the newest program in ${HOME}/.rossumworks." >&2
    if [[ -n "${platform}" ]] && program=$(find_newest_cached_file "${NATIVE_CACHE_DIRECTORY}" \
            "rossumworks-.+-${platform}") && verify_native_program_starts "${program}"; then
        echo "native ${program}"
    elif program=$(find_newest_cached_file "${JAR_CACHE_DIRECTORY}" 'rossumworks-.+\.jar'); then
        echo "jar ${program}"
    else
        echo "The folder ${HOME}/.rossumworks has no program. Download a program from ${RELEASES_PAGE}." >&2
        return 1
    fi
}

mkdir -p "${JAR_CACHE_DIRECTORY}" "${NATIVE_CACHE_DIRECTORY}"
token=$(read_token)
platform=$(find_platform || true)
read -r kind program < <(select_program) || exit 1
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ "${kind}" == "native" ]]; then
    exec "${program}" run "$@"
fi
exec java -jar "${program}" run "$@"
