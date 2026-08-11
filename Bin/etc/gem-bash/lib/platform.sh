#!/usr/bin/env bash
# lib/platform.sh - Platform detection for Gem CLI
# Copyright (C) 2025 HintyCloud - GPL-3.0

# Detect operating system
gem_detect_os() {
    local uname_out
    uname_out="$(uname -s 2>/dev/null || echo "UNKNOWN")"

    case "${uname_out}" in
        Linux*)     GEM_OS="linux"   ;;
        Darwin*)    GEM_OS="macos"   ;;
        CYGWIN*)    GEM_OS="cygwin"  ;;
        MINGW*)     GEM_OS="mingw"   ;;
        MSYS*)      GEM_OS="msys"    ;;
        FreeBSD*)   GEM_OS="freebsd" ;;
        NetBSD*)    GEM_OS="netbsd"  ;;
        OpenBSD*)   GEM_OS="openbsd" ;;
        SunOS*)     GEM_OS="solaris" ;;
        *)          GEM_OS="unknown" ;;
    esac

    export GEM_OS
}

# Detect CPU architecture
gem_detect_arch() {
    local uname_m
    uname_m="$(uname -m 2>/dev/null || echo "unknown")"

    case "${uname_m}" in
        x86_64|amd64)   GEM_ARCH="x86_64"   ;;
        i386|i686)      GEM_ARCH="i386"     ;;
        aarch64|arm64)  GEM_ARCH="aarch64"  ;;
        armv7l|armv7)   GEM_ARCH="armv7"    ;;
        armv6l)         GEM_ARCH="armv6"    ;;
        riscv64)        GEM_ARCH="riscv64"  ;;
        ppc64le)        GEM_ARCH="ppc64le"  ;;
        s390x)          GEM_ARCH="s390x"    ;;
        *)              GEM_ARCH="unknown"  ;;
    esac

    export GEM_ARCH
}

# Detect Linux distribution
gem_detect_distro() {
    GEM_DISTRO="unknown"
    GEM_DISTRO_VERSION=""

    if [[ "${GEM_OS}" != "linux" ]]; then
        return
    fi

    # Try /etc/os-release first (systemd standard)
    if [[ -f /etc/os-release ]]; then
        while IFS='=' read -r key value; do
            # Remove quotes from value
            value="${value%\"}"
            value="${value#\"}"
            case "${key}" in
                ID)             GEM_DISTRO="${value}"         ;;
                VERSION_ID)     GEM_DISTRO_VERSION="${value}" ;;
            esac
        done < /etc/os-release
        return
    fi

    # Fallback: check known files
    if [[ -f /etc/redhat-release ]]; then
        GEM_DISTRO="rhel"
    elif [[ -f /etc/debian_version ]]; then
        GEM_DISTRO="debian"
        GEM_DISTRO_VERSION="$(cat /etc/debian_version 2>/dev/null)"
    elif [[ -f /etc/alpine-release ]]; then
        GEM_DISTRO="alpine"
        GEM_DISTRO_VERSION="$(cat /etc/alpine-release 2>/dev/null)"
    elif [[ -f /etc/arch-release ]]; then
        GEM_DISTRO="arch"
    elif [[ -f /etc/gentoo-release ]]; then
        GEM_DISTRO="gentoo"
    fi

    export GEM_DISTRO GEM_DISTRO_VERSION
}

# Detect shell version and capabilities
gem_detect_shell() {
    GEM_SHELL="${SHELL:-unknown}"
    GEM_BASH_VERSION="${BASH_VERSION:-0}"
    GEM_BASH_MAJOR="${BASH_VERSINFO[0]:-0}"

    # Check for required features
    GEM_HAS_ASSOC_ARRAYS=0
    if [[ "${GEM_BASH_MAJOR}" -ge 4 ]]; then
        GEM_HAS_ASSOC_ARRAYS=1
    fi

    export GEM_SHELL GEM_BASH_VERSION GEM_BASH_MAJOR GEM_HAS_ASSOC_ARRAYS
}

# Detect terminal capabilities
gem_detect_terminal() {
    GEM_TERM="${TERM:-unknown}"
    GEM_TERM_COLS="$(tput cols 2>/dev/null || echo 80)"
    GEM_TERM_LINES="$(tput lines 2>/dev/null || echo 24)"
    GEM_HAS_COLOR=0

    if [[ -n "${TERM}" ]] && [[ "${TERM}" != "dumb" ]] && tput setaf 1 &>/dev/null; then
        GEM_HAS_COLOR=1
    fi

    export GEM_TERM GEM_TERM_COLS GEM_TERM_LINES GEM_HAS_COLOR
}

# Check for required dependencies
gem_detect_deps() {
    GEM_DEPS_MISSING=()
    local deps=("curl" "jq" "mktemp" "date")
    local dep

    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &>/dev/null; then
            GEM_DEPS_MISSING+=("${dep}")
        fi
    done

    # Check optional dependencies
    GEM_HAS_FZF=0
    GEM_HAS_GIT=0
    GEM_HAS_BAT=0
    GEM_HAS_RG=0

    command -v fzf  &>/dev/null && GEM_HAS_FZF=1
    command -v git  &>/dev/null && GEM_HAS_GIT=1
    command -v bat  &>/dev/null && GEM_HAS_BAT=1
    command -v rg   &>/dev/null && GEM_HAS_RG=1

    export GEM_DEPS_MISSING GEM_HAS_FZF GEM_HAS_GIT GEM_HAS_BAT GEM_HAS_RG
}

# Run all platform detections
gem_detect_platform() {
    gem_detect_os
    gem_detect_arch
    gem_detect_distro
    gem_detect_shell
    gem_detect_terminal
    gem_detect_deps
}

# Print platform info
gem_platform_info() {
    gem_detect_platform

    printf "Platform Information\n"
    printf "====================\n"
    printf "  OS:          %s\n" "${GEM_OS}"
    if [[ "${GEM_OS}" == "linux" ]]; then
        printf "  Distro:      %s %s\n" "${GEM_DISTRO}" "${GEM_DISTRO_VERSION}"
    fi
    printf "  Arch:        %s\n" "${GEM_ARCH}"
    printf "  Shell:       %s (Bash %s)\n" "${GEM_SHELL}" "${GEM_BASH_VERSION}"
    printf "  Terminal:    %s (%dx%d)\n" "${GEM_TERM}" "${GEM_TERM_COLS}" "${GEM_TERM_LINES}"
    printf "  Color:       %s\n" "$( [[ ${GEM_HAS_COLOR} -eq 1 ]] && echo 'yes' || echo 'no' )"
    printf "  Assoc Arrays: %s\n" "$( [[ ${GEM_HAS_ASSOC_ARRAYS} -eq 1 ]] && echo 'yes' || echo 'no' )"
    printf "\nOptional Tools:\n"
    printf "  fzf:  %s\n" "$( [[ ${GEM_HAS_FZF} -eq 1 ]] && echo 'yes' || echo 'no' )"
    printf "  git:  %s\n" "$( [[ ${GEM_HAS_GIT} -eq 1 ]] && echo 'yes' || echo 'no' )"
    printf "  bat:  %s\n" "$( [[ ${GEM_HAS_BAT} -eq 1 ]] && echo 'yes' || echo 'no' )"
    printf "  rg:   %s\n" "$( [[ ${GEM_HAS_RG} -eq 1 ]] && echo 'yes' || echo 'no' )"

    if [[ ${#GEM_DEPS_MISSING[@]} -gt 0 ]]; then
        printf "\nMissing required dependencies: %s\n" "${GEM_DEPS_MISSING[*]}"
        return 1
    fi

    return 0
}
