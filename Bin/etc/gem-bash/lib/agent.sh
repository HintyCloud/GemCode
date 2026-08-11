#!/usr/bin/env bash
# lib/agent.sh - Agent loop functions for Gem CLI
# Copyright (C) 2025 HintyCloud - GPL-3.0

# Maximum iterations for agent loop (prevents infinite tool loops)
GEM_AGENT_MAX_ITERATIONS="${GEM_AGENT_MAX_ITERATIONS:-10}"

# --- Agent State ---

# Current agent context
GEM_AGENT_SESSION="default"
GEM_AGENT_MODEL=""
GEM_AGENT_PROVIDER=""
GEM_AGENT_SYSTEM_PROMPT=""
GEM_AGENT_ITERATION=0
GEM_AGENT_RUNNING=0
GEM_AGENT_STOPPED=0

# --- Agent Configuration ---

# Load agent configuration
gem_agent_load_config() {
    local agent="${1:-default}"
    local agent_file="${GEM_CONFIG_DIR}/agents/${agent}.sh"

    GEM_AGENT_MODEL="${GEM_MODEL:-${GEM_DEFAULT_MODEL}}"
    GEM_AGENT_PROVIDER="${GEM_PROVIDER:-${GEM_DEFAULT_PROVIDER}}"
    GEM_AGENT_SYSTEM_PROMPT="${GEM_SYSTEM_PROMPT:-You are Gem, a helpful AI assistant.}"

    if [[ -f "${agent_file}" ]]; then
        source "${agent_file}" 2>/dev/null
    fi

    # Allow environment overrides
    GEM_AGENT_MODEL="${GEM_AGENT_MODEL_OVERRIDE:-${GEM_AGENT_MODEL}}"
    GEM_AGENT_PROVIDER="${GEM_AGENT_PROVIDER_OVERRIDE:-${GEM_AGENT_PROVIDER}}"
}

# --- Message Building ---

# Build the messages array for the API request
gem_agent_build_messages() {
    local session="${1:-${GEM_AGENT_SESSION}}"
    local system_prompt="${2:-${GEM_AGENT_SYSTEM_PROMPT}}"
    local user_message="${3:-}"

    # Start with system message
    local messages
    messages="$(jq -n --arg sp "${system_prompt}" '[{"role":"system","content":$sp}]')"

    # Add memory context if enabled
    if [[ "${GEM_ENABLE_MEMORY:-1}" == "1" ]]; then
        local mem_context
        mem_context="$(gem_memory_context "${session}")"
        if [[ -n "${mem_context}" ]]; then
            messages="$(printf '%s' "${messages}" | jq --arg mc "${mem_context}" \
                '. + [{"role":"system","content":$mc}]')"
        fi
    fi

    # Add conversation history
    local history
    history="$(gem_history_get_messages "${session}")"
    if [[ "${history}" != "[]" ]] && [[ -n "${history}" ]]; then
        messages="$(printf '%s' "${messages}" | jq --argjson hist "${history}" \
            '. + $hist')"
    fi

    # Add new user message if provided
    if [[ -n "${user_message}" ]]; then
        messages="$(printf '%s' "${messages}" | jq --arg msg "${user_message}" \
            '. + [{"role":"user","content":$msg}]')"
    fi

    printf '%s' "${messages}"
}

# --- Agent Loop ---

# Run a single iteration of the agent loop
gem_agent_step() {
    local messages="${1}"
    local session="${2:-${GEM_AGENT_SESSION}}"
    local model="${3:-${GEM_AGENT_MODEL}}"
    local tools_json="${4:-}"

    GEM_AGENT_ITERATION=$((GEM_AGENT_ITERATION + 1))

    if [[ "${GEM_VERBOSE:-0}" == "1" ]]; then
        printf "\n  [Agent iteration %d/%d]\n" "${GEM_AGENT_ITERATION}" "${GEM_AGENT_MAX_ITERATIONS}"
    fi

    # Send request to provider
    local response
    if [[ -n "${tools_json}" ]] && [[ "${GEM_ENABLE_TOOLS:-1}" == "1" ]]; then
        response="$(gem_provider_chat "${model}" "${messages}" "${tools_json}")"
    else
        response="$(gem_provider_chat "${model}" "${messages}" "null")"
    fi

    local rc=$?
    if [[ ${rc} -ne 0 ]]; then
        printf "\n  ❌ API request failed (iteration %d)\n" "${GEM_AGENT_ITERATION}"
        return 1
    fi

    # Parse the response
    local parsed
    parsed="$(gem_provider_parse_response "${response}")"

    local content
    content="$(printf '%s' "${parsed}" | jq -r '.content // empty')"
    local tool_calls
    tool_calls="$(printf '%s' "${parsed}" | jq -c '.tool_calls // []')"
    local usage
    usage="$(printf '%s' "${parsed}" | jq -c '.usage // {}')"

    # Display the assistant's text content
    if [[ -n "${content}" ]]; then
        printf '%s\n' "${content}"
    fi

    # Save assistant message to history
    if [[ "${tool_calls}" != "[]" ]] && [[ -n "${tool_calls}" ]]; then
        gem_history_append_tool_call "${session}" "assistant" "${content}" "${tool_calls}"
    else
        gem_history_append "${session}" "assistant" "${content}"
    fi

    # Show usage if verbose
    if [[ "${GEM_VERBOSE:-0}" == "1" ]] && [[ "${usage}" != "{}" ]]; then
        local prompt_tokens completion_tokens
        prompt_tokens="$(printf '%s' "${usage}" | jq -r '.prompt_tokens // 0')"
        completion_tokens="$(printf '%s' "${usage}" | jq -r '.completion_tokens // 0')"
        printf "\n  [Tokens: prompt=%s, completion=%s]\n" "${prompt_tokens}" "${completion_tokens}"
    fi

    # Process tool calls if any
    if [[ "${tool_calls}" != "[]" ]] && [[ -n "${tool_calls}" ]] && [[ "${GEM_ENABLE_TOOLS:-1}" == "1" ]]; then
        # Execute tools and get results
        local tool_results
        tool_results="$(gem_tool_process_calls "${tool_calls}" "${session}")"

        # Add tool results back to messages and continue the loop
        local updated_messages
        updated_messages="$(printf '%s' "${messages}" | jq --argjson resp "$(printf '%s' "${response}" | jq -c '.choices[0].message')" '. + [$resp]')"

        # Add tool result messages
        local tr_count
        tr_count="$(printf '%s' "${tool_results}" | jq 'length' 2>/dev/null)"
        local i
        for ((i=0; i<tr_count; i++)); do
            local tr
            tr="$(printf '%s' "${tool_results}" | jq -c ".[${i}]")"
            local tr_id tr_content
            tr_id="$(printf '%s' "${tr}" | jq -r '.tool_call_id')"
            tr_content="$(printf '%s' "${tr}" | jq -r '.content')"

            local tool_msg
            tool_msg="$(jq -n \
                --arg call_id "${tr_id}" \
                --arg content "${tr_content}" \
                '{
                    role: "tool",
                    tool_call_id: $call_id,
                    content: $content
                }')"

            updated_messages="$(printf '%s' "${updated_messages}" | jq --argjson tm "${tool_msg}" '. + [$tm]')"
        done

        # Check if we should continue the loop
        if [[ "${GEM_AGENT_ITERATION}" -lt "${GEM_AGENT_MAX_ITERATIONS}" ]]; then
            # Recursive call for next iteration
            gem_agent_step "${updated_messages}" "${session}" "${model}" "${tools_json}"
            return $?
        else
            printf "\n  ⚠️  Maximum iterations reached (%d)\n" "${GEM_AGENT_MAX_ITERATIONS}"
            return 2
        fi
    fi

    # No tool calls - agent loop is done
    return 0
}

# Main agent entry point - send a message and run the loop
gem_agent_run() {
    local user_message="${1}"
    local session="${2:-${GEM_AGENT_SESSION}}"
    local model="${3:-${GEM_AGENT_MODEL}}"

    if [[ -z "${user_message}" ]]; then
        printf "Error: no message provided\n" >&2
        return 1
    fi

    # Reset iteration counter
    GEM_AGENT_ITERATION=0

    # Save user message to history
    gem_history_append "${session}" "user" "${user_message}"

    # Build messages array
    local messages
    messages="$(gem_agent_build_messages "${session}" "${GEM_AGENT_SYSTEM_PROMPT}")"

    # Build tools schema
    local tools_json="null"
    if [[ "${GEM_ENABLE_TOOLS:-1}" == "1" ]]; then
        tools_json="$(gem_tools_build_schema)"
    fi

    # Run the agent loop
    gem_agent_step "${messages}" "${session}" "${model}" "${tools_json}"
}

# Run agent with streaming (simplified - no tool support in stream mode)
gem_agent_run_stream() {
    local user_message="${1}"
    local session="${2:-${GEM_AGENT_SESSION}}"
    local model="${3:-${GEM_AGENT_MODEL}}"

    if [[ -z "${user_message}" ]]; then
        printf "Error: no message provided\n" >&2
        return 1
    fi

    # Save user message to history
    gem_history_append "${session}" "user" "${user_message}"

    # Build messages
    local messages
    messages="$(gem_agent_build_messages "${session}" "${GEM_AGENT_SYSTEM_PROMPT}")"

    # Build request (streaming, no tools)
    local req
    req="$(gem_provider_build_request "${model}" "${messages}" "${GEM_TEMPERATURE:-0.7}" "${GEM_MAX_TOKENS:-4096}" "null" "true")"

    # Stream the response
    local full_content=""
    local chunk

    gem_provider_post_stream "/chat/completions" "${req}" | while IFS= read -r chunk; do
        # Parse SSE data
        chunk="${chunk#data: }"
        chunk="${chunk#data:}"

        [[ "${chunk}" == "[DONE]" ]] && break
        [[ -z "${chunk}" ]] && continue

        local delta
        delta="$(printf '%s' "${chunk}" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)"

        if [[ -n "${delta}" ]]; then
            printf '%s' "${delta}"
        fi
    done

    printf '\n'
}

# --- Agent Management ---

# List available agents
gem_agent_list() {
    local agent_dir="${GEM_CONFIG_DIR}/agents"

    printf "Agents\n"
    printf "======\n\n"
    printf "  %-20s %s\n" "default" "(built-in)"

    if [[ -d "${agent_dir}" ]]; then
        local f
        for f in "${agent_dir}"/*.sh; do
            if [[ -f "${f}" ]]; then
                local name
                name="$(basename "${f}" .sh)"
                [[ "${name}" == "default" ]] && continue
                printf "  %-20s %s\n" "${name}" "${f}"
            fi
        done
    fi
}

# Show agent status
gem_agent_status() {
    printf "Agent Status\n"
    printf "============\n"
    printf "  Session:     %s\n" "${GEM_AGENT_SESSION}"
    printf "  Model:       %s\n" "${GEM_AGENT_MODEL}"
    printf "  Provider:    %s\n" "${GEM_AGENT_PROVIDER}"
    printf "  Iteration:   %d\n" "${GEM_AGENT_ITERATION}"
    printf "  Max Iter:    %d\n" "${GEM_AGENT_MAX_ITERATIONS}"
    printf "  Tools:       %s\n" "$( [[ ${GEM_ENABLE_TOOLS:-1} -eq 1 ]] && echo 'enabled' || echo 'disabled' )"
    printf "  Memory:      %s\n" "$( [[ ${GEM_ENABLE_MEMORY:-1} -eq 1 ]] && echo 'enabled' || echo 'disabled' )"
    printf "  Streaming:   %s\n" "$( [[ ${GEM_ENABLE_STREAMING:-1} -eq 1 ]] && echo 'enabled' || echo 'disabled' )"

    local msg_count
    msg_count="$(gem_history_count "${GEM_AGENT_SESSION}")"
    printf "  Messages:    %s\n" "${msg_count}"
}

# Initialize agent
gem_agent_init() {
    local session="${1:-default}"
    local agent="${2:-default}"

    GEM_AGENT_SESSION="${session}"
    GEM_AGENT_ITERATION=0
    GEM_AGENT_RUNNING=0
    GEM_AGENT_STOPPED=0

    gem_agent_load_config "${agent}"
    gem_history_init "${session}"
}
