#!/usr/bin/env bash
# lib/config.sh - Configuration loading for Gem CLI
# Copyright (C) 2025 HintyCloud - GPL-3.0

# Defaults
GEM_VERSION="1.0.0"
GEM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gem"
GEM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gem"
GEM_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gem"
GEM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/gem"

GEM_DEFAULT_MODEL="opencode/default"
GEM_DEFAULT_PROVIDER="opencode"
GEM_DEFAULT_TEMPERATURE="0.7"
GEM_DEFAULT_MAX_TOKENS="4096"
GEM_DEFAULT_TIMEOUT="30"
GEM_DEFAULT_HISTORY_SIZE="1000"

# Create config directories
gem_config_init_dirs() {
    local dirs=(
        "${GEM_CONFIG_DIR}"
        "${GEM_DATA_DIR}"
        "${GEM_CACHE_DIR}"
        "${GEM_STATE_DIR}"
        "${GEM_CONFIG_DIR}/providers"
        "${GEM_CONFIG_DIR}/agents"
        "${GEM_CONFIG_DIR}/projects"
        "${GEM_DATA_DIR}/memory"
        "${GEM_DATA_DIR}/history"
        "${GEM_STATE_DIR}/jobs"
    )
    local d
    for d in "${dirs[@]}"; do
        mkdir -p "${d}" 2>/dev/null || true
    done
}

# Load main config file (shell sourceable)
gem_config_load_file() {
    local config_file="${1:-${GEM_CONFIG_DIR}/config.sh}"

    if [[ -f "${config_file}" ]]; then
        # shellcheck source=/dev/null
        source "${config_file}" 2>/dev/null
        return 0
    fi
    return 1
}

# Load a key-value config file (KEY=VALUE format, # comments)
gem_config_load_kv() {
    local config_file="${1:-${GEM_CONFIG_DIR}/config.env}"
    local line key value

    if [[ ! -f "${config_file}" ]]; then
        return 1
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip comments and blank lines
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Parse KEY=VALUE
        if [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Strip surrounding quotes
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            # Export only GEM_ prefixed variables
            if [[ "${key}" == GEM_* ]]; then
                export "${key}=${value}"
            fi
        fi
    done < "${config_file}"

    return 0
}

# Load provider-specific config
gem_config_load_provider() {
    local provider="${1:-${GEM_DEFAULT_PROVIDER}}"
    local provider_file="${GEM_CONFIG_DIR}/providers/${provider}.sh"

    if [[ -f "${provider_file}" ]]; then
        source "${provider_file}" 2>/dev/null
        return 0
    fi
    return 1
}

# Load agent-specific config
gem_config_load_agent() {
    local agent="${1:-default}"
    local agent_file="${GEM_CONFIG_DIR}/agents/${agent}.sh"

    if [[ -f "${agent_file}" ]]; then
        source "${agent_file}" 2>/dev/null
        return 0
    fi
    return 1
}

# Set a config value
gem_config_set() {
    local key="${1}"
    local value="${2}"
    local config_file="${GEM_CONFIG_DIR}/config.env"

    gem_config_init_dirs

    # Remove existing key if present
    if [[ -f "${config_file}" ]]; then
        local tmp
        tmp="$(mktemp)"
        while IFS= read -r line || [[ -n "${line}" ]]; do
            if [[ "${line}" =~ ^[[:space:]]*${key}= ]]; then
                continue
            fi
            printf '%s\n' "${line}" >> "${tmp}"
        done < "${config_file}"
        mv "${tmp}" "${config_file}"
    fi

    # Append new value
    printf '%s=%s\n' "${key}" "${value}" >> "${config_file}"
    export "${key}=${value}"
}

# Get a config value
gem_config_get() {
    local key="${1}"
    local default="${2:-}"

    # Check environment first
    if [[ -n "${!key:-}" ]]; then
        printf '%s\n' "${!key}"
        return 0
    fi

    # Check config file
    local config_file="${GEM_CONFIG_DIR}/config.env"
    if [[ -f "${config_file}" ]]; then
        local line k v
        while IFS= read -r line || [[ -n "${line}" ]]; do
            [[ "${line}" =~ ^[[:space:]]*# ]] && continue
            if [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
                k="${BASH_REMATCH[1]}"
                v="${BASH_REMATCH[2]}"
                v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"
                if [[ "${k}" == "${key}" ]]; then
                    printf '%s\n' "${v}"
                    return 0
                fi
            fi
        done < "${config_file}"
    fi

    printf '%s\n' "${default}"
    return 1
}

# Unset a config value
gem_config_unset() {
    local key="${1}"
    local config_file="${GEM_CONFIG_DIR}/config.env"

    if [[ -f "${config_file}" ]]; then
        local tmp
        tmp="$(mktemp)"
        while IFS= read -r line || [[ -n "${line}" ]]; do
            if [[ "${line}" =~ ^[[:space:]]*${key}= ]]; then
                continue
            fi
            printf '%s\n' "${line}" >> "${tmp}"
        done < "${config_file}"
        mv "${tmp}" "${config_file}"
    fi

    unset "${key}" 2>/dev/null || true
}

# List all config values
gem_config_list() {
    local config_file="${GEM_CONFIG_DIR}/config.env"

    if [[ ! -f "${config_file}" ]]; then
        printf "No configuration file found at %s\n" "${config_file}"
        return 0
    fi

    printf "Configuration (%s)\n" "${config_file}"
    printf "======================\n"

    local line key value
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        if [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            value="${value#\"}"; value="${value%\"}"
            printf "  %-30s = %s\n" "${key}" "${value}"
        fi
    done < "${config_file}"
}

# Generate default config file if none exists
gem_config_generate_default() {
    local config_file="${GEM_CONFIG_DIR}/config.env"

    if [[ -f "${config_file}" ]]; then
        return 0
    fi

    gem_config_init_dirs

    cat > "${config_file}" << 'EOF'
# Gem CLI Configuration
# Generated by gem v1.0.0

# API Configuration
GEM_API_URL=https://api.opencode.dev/v1
GEM_API_KEY=
GEM_DEFAULT_MODEL=opencode/default
GEM_DEFAULT_PROVIDER=opencode

# Model Parameters
GEM_TEMPERATURE=0.7
GEM_MAX_TOKENS=4096
GEM_TIMEOUT=30

# Chat Settings
GEM_HISTORY_SIZE=1000
GEM_SYSTEM_PROMPT=You are Gem, a helpful AI assistant.

# Feature Flags
GEM_ENABLE_TOOLS=1
GEM_ENABLE_MEMORY=1
GEM_ENABLE_STREAMING=1

# Display
GEM_SHOW_TOKENS=0
GEM_VERBOSE=0
EOF

    printf "Generated default config at %s\n" "${config_file}"
}

# Initialize full configuration
gem_config_init() {
    # Create directories
    gem_config_init_dirs

    # Load env-style config
    gem_config_load_kv "${GEM_CONFIG_DIR}/config.env"

    # Load shell-style config (overrides env-style)
    gem_config_load_file "${GEM_CONFIG_DIR}/config.sh"

    # Apply environment variable overrides
    GEM_API_URL="${GEM_API_URL:-https://api.opencode.dev/v1}"
    GEM_API_KEY="${GEM_API_KEY:-}"
    GEM_MODEL="${GEM_MODEL:-${GEM_DEFAULT_MODEL}}"
    GEM_PROVIDER="${GEM_PROVIDER:-${GEM_DEFAULT_PROVIDER}}"
    GEM_TEMPERATURE="${GEM_TEMPERATURE:-${GEM_DEFAULT_TEMPERATURE}}"
    GEM_MAX_TOKENS="${GEM_MAX_TOKENS:-${GEM_DEFAULT_MAX_TOKENS}}"
    GEM_TIMEOUT="${GEM_TIMEOUT:-${GEM_DEFAULT_TIMEOUT}}"
    GEM_HISTORY_SIZE="${GEM_HISTORY_SIZE:-${GEM_DEFAULT_HISTORY_SIZE}}"
    GEM_SYSTEM_PROMPT="${GEM_SYSTEM_PROMPT:-You are Gem, a helpful AI assistant.}"
    GEM_ENABLE_TOOLS="${GEM_ENABLE_TOOLS:-1}"
    GEM_ENABLE_MEMORY="${GEM_ENABLE_MEMORY:-1}"
    GEM_ENABLE_STREAMING="${GEM_ENABLE_STREAMING:-1}"
    GEM_VERBOSE="${GEM_VERBOSE:-0}"

    # Load provider config
    gem_config_load_provider "${GEM_PROVIDER}"

    export GEM_API_URL GEM_API_KEY GEM_MODEL GEM_PROVIDER \
           GEM_TEMPERATURE GEM_MAX_TOKENS GEM_TIMEOUT \
           GEM_HISTORY_SIZE GEM_SYSTEM_PROMPT \
           GEM_ENABLE_TOOLS GEM_ENABLE_MEMORY GEM_ENABLE_STREAMING \
           GEM_VERBOSE
}
