#!/usr/bin/env bash
# lib/memory.sh - Memory and history functions for Gem CLI
# Copyright (C) 2025 HintyCloud - GPL-3.0

# --- Conversation History ---

# Get history file path for a session
gem_history_file() {
    local session="${1:-default}"
    printf '%s\n' "${GEM_DATA_DIR}/history/${session}.json"
}

# Initialize a new conversation history
gem_history_init() {
    local session="${1:-default}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    if [[ ! -f "${hfile}" ]]; then
        printf '{"session":"%s","created":"%s","messages":[]}\n' \
            "${session}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${hfile}"
    fi
}

# Append a message to conversation history
gem_history_append() {
    local session="${1:-default}"
    local role="${2:-user}"      # user, assistant, system, tool
    local content="${3:-}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    gem_history_init "${session}"

    # Build the new message JSON
    local msg
    msg="$(printf '{"role":"%s","content":"%s","timestamp":"%s"}' \
        "${role}" \
        "$(printf '%s' "${content}" | jq -Rs . | sed 's/^"//;s/"$//')" \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"

    # Append to messages array
    local tmp
    tmp="$(mktemp)"
    jq --argjson msg "${msg}" '.messages += [$msg]' "${hfile}" > "${tmp}" 2>/dev/null
    if [[ -s "${tmp}" ]]; then
        mv "${tmp}" "${hfile}"
    else
        rm -f "${tmp}"
    fi
}

# Append a message with tool_calls to history
gem_history_append_tool_call() {
    local session="${1:-default}"
    local role="${2:-assistant}"
    local content="${3:-}"
    local tool_calls_json="${4:-[]}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    gem_history_init "${session}"

    local msg
    msg="$(printf '{"role":"%s","content":"%s","tool_calls":%s,"timestamp":"%s"}' \
        "${role}" \
        "$(printf '%s' "${content}" | jq -Rs . | sed 's/^"//;s/"$//')" \
        "${tool_calls_json}" \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"

    local tmp
    tmp="$(mktemp)"
    jq --argjson msg "${msg}" '.messages += [$msg]' "${hfile}" > "${tmp}" 2>/dev/null
    if [[ -s "${tmp}" ]]; then
        mv "${tmp}" "${hfile}"
    else
        rm -f "${tmp}"
    fi
}

# Get conversation messages as JSON array
gem_history_get_messages() {
    local session="${1:-default}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    if [[ -f "${hfile}" ]]; then
        jq -c '.messages' "${hfile}" 2>/dev/null
    else
        printf '[]'
    fi
}

# Get conversation message count
gem_history_count() {
    local session="${1:-default}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    if [[ -f "${hfile}" ]]; then
        jq '.messages | length' "${hfile}" 2>/dev/null
    else
        printf '0'
    fi
}

# Clear conversation history
gem_history_clear() {
    local session="${1:-default}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    if [[ -f "${hfile}" ]]; then
        rm -f "${hfile}"
        printf "History cleared for session: %s\n" "${session}"
    fi
}

# List all sessions
gem_history_list_sessions() {
    local hdir="${GEM_DATA_DIR}/history"
    if [[ -d "${hdir}" ]]; then
        local f
        for f in "${hdir}"/*.json; do
            if [[ -f "${f}" ]]; then
                local name
                name="$(basename "${f}" .json)"
                local count
                count="$(jq '.messages | length' "${f}" 2>/dev/null || echo 0)"
                local created
                created="$(jq -r '.created' "${f}" 2>/dev/null || echo 'unknown')"
                printf "  %-20s %4d messages  %s\n" "${name}" "${count}" "${created}"
            fi
        done
    else
        printf "  No sessions found.\n"
    fi
}

# Trim history to max size (keep most recent)
gem_history_trim() {
    local session="${1:-default}"
    local max="${2:-${GEM_HISTORY_SIZE}}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    if [[ ! -f "${hfile}" ]]; then
        return
    fi

    local count
    count="$(jq '.messages | length' "${hfile}" 2>/dev/null)"

    if [[ "${count}" -gt "${max}" ]]; then
        local tmp
        tmp="$(mktemp)"
        jq --argjson max "${max}" '.messages |= .[-$max:]' "${hfile}" > "${tmp}" 2>/dev/null
        if [[ -s "${tmp}" ]]; then
            mv "${tmp}" "${hfile}"
        else
            rm -f "${tmp}"
        fi
    fi
}

# Export conversation as Markdown
gem_history_export_markdown() {
    local session="${1:-default}"
    local outfile="${2:-}"
    local hfile
    hfile="$(gem_history_file "${session}")"

    if [[ ! -f "${hfile}" ]]; then
        printf "No history found for session: %s\n" "${session}"
        return 1
    fi

    local output=""
    output+="# Gem Chat Export: ${session}\n"
    output+="Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)\n\n---\n\n"

    local count
    count="$(jq '.messages | length' "${hfile}" 2>/dev/null)"
    local i role content

    for ((i=0; i<count; i++)); do
        role="$(jq -r ".messages[${i}].role" "${hfile}" 2>/dev/null)"
        content="$(jq -r ".messages[${i}].content" "${hfile}" 2>/dev/null)"

        case "${role}" in
            system)    output+="**System:** ${content}\n\n" ;;
            user)      output+="**User:** ${content}\n\n" ;;
            assistant) output+="**Gem:** ${content}\n\n" ;;
            tool)      output+="**Tool:** ${content}\n\n" ;;
            *)         output+="**${role}:** ${content}\n\n" ;;
        esac
    done

    if [[ -n "${outfile}" ]]; then
        printf '%b\n' "${output}" > "${outfile}"
        printf "Exported to %s\n" "${outfile}"
    else
        printf '%b\n' "${output}"
    fi
}

# --- Long-term Memory ---

# Get memory file path
gem_memory_file() {
    local namespace="${1:-default}"
    printf '%s\n' "${GEM_DATA_DIR}/memory/${namespace}.json"
}

# Initialize memory store
gem_memory_init() {
    local namespace="${1:-default}"
    local mfile
    mfile="$(gem_memory_file "${namespace}")"

    if [[ ! -f "${mfile}" ]]; then
        printf '{"namespace":"%s","entries":{}}' "${namespace}" > "${mfile}"
    fi
}

# Save a memory entry
gem_memory_save() {
    local namespace="${1:-default}"
    local key="${2}"
    local value="${3}"
    local mfile
    mfile="$(gem_memory_file "${namespace}")"

    gem_memory_init "${namespace}"

    local tmp
    tmp="$(mktemp)"
    jq --arg key "${key}" --arg value "${value}" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.entries[$key] = {"value": $value, "updated": $ts}' \
       "${mfile}" > "${tmp}" 2>/dev/null
    if [[ -s "${tmp}" ]]; then
        mv "${tmp}" "${mfile}"
    else
        rm -f "${tmp}"
    fi
}

# Recall a memory entry
gem_memory_recall() {
    local namespace="${1:-default}"
    local key="${2}"
    local mfile
    mfile="$(gem_memory_file "${namespace}")"

    if [[ -f "${mfile}" ]]; then
        jq -r --arg key "${key}" '.entries[$key].value // empty' "${mfile}" 2>/dev/null
    fi
}

# Delete a memory entry
gem_memory_delete() {
    local namespace="${1:-default}"
    local key="${2}"
    local mfile
    mfile="$(gem_memory_file "${namespace}")"

    if [[ -f "${mfile}" ]]; then
        local tmp
        tmp="$(mktemp)"
        jq --arg key "${key}" 'del(.entries[$key])' "${mfile}" > "${tmp}" 2>/dev/null
        if [[ -s "${tmp}" ]]; then
            mv "${tmp}" "${mfile}"
        else
            rm -f "${tmp}"
        fi
    fi
}

# List all memory entries
gem_memory_list() {
    local namespace="${1:-default}"
    local mfile
    mfile="$(gem_memory_file "${namespace}")"

    if [[ -f "${mfile}" ]]; then
        local keys
        keys="$(jq -r '.entries | keys[]' "${mfile}" 2>/dev/null)"
        if [[ -n "${keys}" ]]; then
            local k v ts
            while IFS= read -r k; do
                v="$(jq -r --arg k "${k}" '.entries[$k].value' "${mfile}" 2>/dev/null)"
                ts="$(jq -r --arg k "${k}" '.entries[$k].updated' "${mfile}" 2>/dev/null)"
                printf "  %-20s = %s  (updated: %s)\n" "${k}" "${v}" "${ts}"
            done <<< "${keys}"
        else
            printf "  No memories stored.\n"
        fi
    else
        printf "  No memory file found.\n"
    fi
}

# Build context string from memory for prompt injection
gem_memory_context() {
    local namespace="${1:-default}"
    local mfile
    mfile="$(gem_memory_file "${namespace}")"

    if [[ -f "${mfile}" ]]; then
        local context=""
        local keys
        keys="$(jq -r '.entries | keys[]' "${mfile}" 2>/dev/null)"
        if [[ -n "${keys}" ]]; then
            context+="[Memory Context]\n"
            local k v
            while IFS= read -r k; do
                v="$(jq -r --arg k "${k}" '.entries[$k].value' "${mfile}" 2>/dev/null)"
                context+="${k}: ${v}\n"
            done <<< "${keys}"
            printf '%b' "${context}"
        fi
    fi
}
