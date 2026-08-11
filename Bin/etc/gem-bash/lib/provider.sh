#!/usr/bin/env bash
# lib/provider.sh - Provider functions (OpenCode API via curl) for Gem CLI
# Copyright (C) 2025 HintyCloud - GPL-3.0

# --- Provider Registry ---

# Initialize provider registry (Bash 4+ associative array)
declare -gA GEM_PROVIDERS=()
declare -gA GEM_PROVIDER_MODELS=()

# Register built-in providers
gem_provider_register_builtins() {
    GEM_PROVIDERS[opencode]="OpenCode API"
    GEM_PROVIDERS[openai]="OpenAI API"
    GEM_PROVIDERS[anthropic]="Anthropic API"
    GEM_PROVIDERS[local]="Local Server"

    GEM_PROVIDER_MODELS[opencode]="opencode/default opencode/advanced opencode/code opencode/chat"
    GEM_PROVIDER_MODELS[openai]="gpt-4o gpt-4o-mini gpt-4-turbo gpt-3.5-turbo"
    GEM_PROVIDER_MODELS[anthropic]="claude-sonnet-4-20250514 claude-haiku-4-20250514 claude-3-5-sonnet-20241022"
    GEM_PROVIDER_MODELS[local]="local/default"
}

# --- API Endpoint Builders ---

# Get base URL for a provider
gem_provider_base_url() {
    local provider="${1:-${GEM_PROVIDER}}"

    case "${provider}" in
        opencode)   printf '%s' "${GEM_API_URL:-https://api.opencode.dev/v1}" ;;
        openai)     printf '%s' "${GEM_OPENAI_URL:-https://api.openai.com/v1}" ;;
        anthropic)  printf '%s' "${GEM_ANTHROPIC_URL:-https://api.anthropic.com/v1}" ;;
        local)      printf '%s' "${GEM_LOCAL_URL:-http://localhost:8080/v1}" ;;
        *)          printf '%s' "${GEM_API_URL:-https://api.opencode.dev/v1}" ;;
    esac
}

# Get API key for a provider
gem_provider_api_key() {
    local provider="${1:-${GEM_PROVIDER}}"

    case "${provider}" in
        opencode)   printf '%s' "${GEM_API_KEY:-}" ;;
        openai)     printf '%s' "${GEM_OPENAI_API_KEY:-${OPENAI_API_KEY:-}}" ;;
        anthropic)  printf '%s' "${GEM_ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:-}}" ;;
        local)      printf '%s' "${GEM_LOCAL_API_KEY:-local}" ;;
        *)          printf '%s' "${GEM_API_KEY:-}" ;;
    esac
}

# --- HTTP Helpers ---

# Build common curl arguments
gem_curl_args() {
    local provider="${1:-${GEM_PROVIDER}}"
    local base_url
    base_url="$(gem_provider_base_url "${provider}")"
    local api_key
    api_key="$(gem_provider_api_key "${provider}")"
    local timeout="${GEM_TIMEOUT:-30}"

    local args=(
        -s
        --max-time "${timeout}"
        -H "Content-Type: application/json"
    )

    if [[ -n "${api_key}" ]]; then
        args+=(-H "Authorization: Bearer ${api_key}")
    fi

    printf '%s\n' "${args[@]}"
}

# Make a GET request
gem_provider_get() {
    local path="${1}"
    local provider="${2:-${GEM_PROVIDER}}"
    local base_url
    base_url="$(gem_provider_base_url "${provider}")"
    local api_key
    api_key="$(gem_provider_api_key "${provider}")"
    local timeout="${GEM_TIMEOUT:-30}"

    local curl_args=(
        -s
        --max-time "${timeout}"
        -H "Content-Type: application/json"
    )

    if [[ -n "${api_key}" ]]; then
        curl_args+=(-H "Authorization: Bearer ${api_key}")
    fi

    curl "${curl_args[@]}" "${base_url}${path}" 2>/dev/null
}

# Make a POST request
gem_provider_post() {
    local path="${1}"
    local data="${2}"
    local provider="${3:-${GEM_PROVIDER}}"
    local base_url
    base_url="$(gem_provider_base_url "${provider}")"
    local api_key
    api_key="$(gem_provider_api_key "${provider}")"
    local timeout="${GEM_TIMEOUT:-30}"

    local curl_args=(
        -s
        --max-time "${timeout}"
        -X POST
        -H "Content-Type: application/json"
    )

    if [[ -n "${api_key}" ]]; then
        curl_args+=(-H "Authorization: Bearer ${api_key}")
    fi

    curl "${curl_args[@]}" -d "${data}" "${base_url}${path}" 2>/dev/null
}

# Make a streaming POST request (prints raw SSE to stdout)
gem_provider_post_stream() {
    local path="${1}"
    local data="${2}"
    local provider="${3:-${GEM_PROVIDER}}"
    local base_url
    base_url="$(gem_provider_base_url "${provider}")"
    local api_key
    api_key="$(gem_provider_api_key "${provider}")"
    local timeout="${GEM_TIMEOUT:-120}"

    local curl_args=(
        -s
        --max-time "${timeout}"
        -N
        -X POST
        -H "Content-Type: application/json"
    )

    if [[ -n "${api_key}" ]]; then
        curl_args+=(-H "Authorization: Bearer ${api_key}")
    fi

    curl "${curl_args[@]}" -d "${data}" "${base_url}${path}" 2>/dev/null
}

# --- Chat Completion ---

# Build the request payload for chat completions
gem_provider_build_request() {
    local model="${1:-${GEM_MODEL}}"
    local messages="${2:-[]}"
    local temperature="${3:-${GEM_TEMPERATURE:-0.7}}"
    local max_tokens="${4:-${GEM_MAX_TOKENS:-4096}}"
    local tools="${5:-null}"
    local stream="${6:-false}"

    local req
    req="$(jq -n \
        --arg model "${model}" \
        --argjson temperature "${temperature}" \
        --argjson max_tokens "${max_tokens}" \
        --argjson stream "${stream}" \
        '{
            model: $model,
            temperature: $temperature,
            max_tokens: $max_tokens,
            stream: $stream
        }')"

    # Add messages
    req="$(printf '%s' "${req}" | jq --argjson msgs "${messages}" '. + {messages: $msgs}')"

    # Add tools if provided
    if [[ "${tools}" != "null" ]] && [[ "${tools}" != "[]" ]] && [[ "${GEM_ENABLE_TOOLS:-1}" == "1" ]]; then
        req="$(printf '%s' "${req}" | jq --argjson tools "${tools}" '. + {tools: $tools}')"
    fi

    printf '%s' "${req}"
}

# Send a chat completion request (non-streaming)
gem_provider_chat() {
    local model="${1:-${GEM_MODEL}}"
    local messages="${2:-[]}"
    local tools="${3:-null}"

    local req
    req="$(gem_provider_build_request "${model}" "${messages}" "${GEM_TEMPERATURE:-0.7}" "${GEM_MAX_TOKENS:-4096}" "${tools}" "false")"

    local response
    response="$(gem_provider_post "/chat/completions" "${req}")"

    # Check for errors
    if printf '%s' "${response}" | jq -e '.error' &>/dev/null; then
        local err_msg
        err_msg="$(printf '%s' "${response}" | jq -r '.error.message // "Unknown error"')"
        printf '{"error":"%s"}\n' "${err_msg}" >&2
        return 1
    fi

    printf '%s' "${response}"
}

# Send a streaming chat completion request
gem_provider_chat_stream() {
    local model="${1:-${GEM_MODEL}}"
    local messages="${2:-[]}"
    local tools="${3:-null}"

    local req
    req="$(gem_provider_build_request "${model}" "${messages}" "${GEM_TEMPERATURE:-0.7}" "${GEM_MAX_TOKENS:-4096}" "${tools}" "true")"

    gem_provider_post_stream "/chat/completions" "${req}"
}

# Parse a non-streaming response
gem_provider_parse_response() {
    local response="${1}"

    # Extract the assistant message content
    local content
    content="$(printf '%s' "${response}" | jq -r '.choices[0].message.content // empty' 2>/dev/null)"

    # Extract tool_calls if present
    local tool_calls
    tool_calls="$(printf '%s' "${response}" | jq -c '.choices[0].message.tool_calls // empty' 2>/dev/null)"

    # Extract usage info
    local usage
    usage="$(printf '%s' "${response}" | jq -c '.usage // empty' 2>/dev/null)"

    # Return structured result
    jq -n \
        --arg content "${content}" \
        --argjson tool_calls "${tool_calls:-[]}" \
        --argjson usage "${usage:-{}}" \
        '{content: $content, tool_calls: $tool_calls, usage: $usage}'
}

# Parse a single SSE chunk
gem_provider_parse_chunk() {
    local chunk="${1}"

    # SSE format: data: {...}
    local data
    data="${chunk#data: }"
    data="${data#data:}"

    # Skip [DONE]
    if [[ "${data}" == "[DONE]" ]] || [[ -z "${data}" ]]; then
        return 1
    fi

    # Extract delta content
    local delta
    delta="$(printf '%s' "${data}" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)"

    if [[ -n "${delta}" ]]; then
        printf '%s' "${delta}"
        return 0
    fi

    return 1
}

# --- Provider Info ---

# List available models for a provider
gem_provider_list_models() {
    local provider="${1:-${GEM_PROVIDER}}"
    local base_url
    base_url="$(gem_provider_base_url "${provider}")"
    local api_key
    api_key="$(gem_provider_api_key "${provider}")"

    local response
    response="$(gem_provider_get "/models")"

    if printf '%s' "${response}" | jq -e '.data' &>/dev/null; then
        printf '%s' "${response}" | jq -r '.data[].id' 2>/dev/null
    else
        # Fall back to static model list
        printf '%s' "${GEM_PROVIDER_MODELS[${provider}]:-}" | tr ' ' '\n'
    fi
}

# Test provider connectivity
gem_provider_test() {
    local provider="${1:-${GEM_PROVIDER}}"
    local base_url
    base_url="$(gem_provider_base_url "${provider}")"

    local start end elapsed
    start="$(date +%s%N)"

    local response
    response="$(gem_provider_get "/models" 2>/dev/null)"
    local rc=$?

    end="$(date +%s%N)"
    elapsed=$(( (end - start) / 1000000 ))

    if [[ ${rc} -eq 0 ]] && [[ -n "${response}" ]]; then
        printf "Provider: %s\n" "${provider}"
        printf "URL:      %s\n" "${base_url}"
        printf "Status:   OK (%dms)\n" "${elapsed}"
        return 0
    else
        printf "Provider: %s\n" "${provider}"
        printf "URL:      %s\n" "${base_url}"
        printf "Status:   FAILED (curl exit: %d, %dms)\n" "${rc}" "${elapsed}"
        return 1
    fi
}

# List all registered providers
gem_provider_list() {
    local p
    printf "Registered Providers\n"
    printf "====================\n\n"
    for p in "${!GEM_PROVIDERS[@]}"; do
        local is_active=""
        if [[ "${p}" == "${GEM_PROVIDER}" ]]; then
            is_active=" (active)"
        fi
        printf "  %-15s %s%s\n" "${p}" "${GEM_PROVIDERS[${p}]}" "${is_active}"
    done
}

# --- Provider Initialization ---

gem_provider_init() {
    gem_provider_register_builtins
}
