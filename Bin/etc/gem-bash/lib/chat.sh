#!/usr/bin/env bash
# lib/chat.sh - Interactive chat REPL for Gem CLI
# Copyright (C) 2025 HintyCloud - GPL-3.0

# Chat state
GEM_CHAT_SESSION="default"
GEM_CHAT_RUNNING=0
GEM_CHAT_MULTILINE=0
GEM_CHAT_MULTILINE_BUFFER=""

# --- Color/Formatting Helpers ---

gem_chat_color_user()     { printf '\033[1;36m%s\033[0m\n' "$1"; }
gem_chat_color_assistant(){ printf '\033[1;32m%s\033[0m\n' "$1"; }
gem_chat_color_system()   { printf '\033[1;33m%s\033[0m\n' "$1"; }
gem_chat_color_error()    { printf '\033[1;31m%s\033[0m\n' "$1"; }
gem_chat_color_dim()      { printf '\033[2m%s\033[0m\n' "$1"; }
gem_chat_color_bold()     { printf '\033[1m%s\033[0m\n' "$1"; }

# --- Slash Commands ---

# Display help for slash commands
gem_chat_slash_help() {
    printf "\n"
    gem_chat_color_bold "Gem Chat Commands"
    printf "  /help              Show this help message\n"
    printf "  /status            Show agent status\n"
    printf "  /model [name]      Get or set the current model\n"
    printf "  /provider [name]   Get or set the current provider\n"
    printf "  /system [prompt]   Get or set the system prompt\n"
    printf "  /clear             Clear conversation history\n"
    printf "  /history           Show conversation history\n"
    printf "  /export [file]     Export conversation as Markdown\n"
    printf "  /memory [key] [v]  Recall or save memory\n"
    printf "  /forget [key]      Delete a memory entry\n"
    printf "  /tools             List available tools\n"
    printf "  /tools [on|off]    Enable or disable tools\n"
    printf "  /multiline         Toggle multiline input mode\n"
    printf "  /session [name]    Switch or list sessions\n"
    printf "  /verbose [on|off]  Toggle verbose mode\n"
    printf "  /save              Save current config\n"
    printf "  /reset             Reset conversation and agent\n"
    printf "  /quit, /exit       Exit chat\n"
    printf "\n"
}

# Process a slash command
gem_chat_slash_command() {
    local input="${1}"
    local cmd
    cmd="$(printf '%s' "${input}" | awk '{print $1}')"
    local args
    args="$(printf '%s' "${input#${cmd}}" | sed 's/^[[:space:]]*//')"

    case "${cmd}" in
        /help|h|/?)
            gem_chat_slash_help
            ;;

        /status)
            gem_agent_status
            ;;

        /model)
            if [[ -n "${args}" ]]; then
                GEM_AGENT_MODEL="${args}"
                GEM_MODEL="${args}"
                gem_chat_color_system "Model set to: ${args}"
            else
                printf "Current model: %s\n" "${GEM_AGENT_MODEL}"
                printf "\nAvailable models:\n"
                gem_provider_list_models "${GEM_AGENT_PROVIDER}" | while IFS= read -r m; do
                    if [[ "${m}" == "${GEM_AGENT_MODEL}" ]]; then
                        printf "  * %s\n" "${m}"
                    else
                        printf "    %s\n" "${m}"
                    fi
                done
            fi
            ;;

        /provider)
            if [[ -n "${args}" ]]; then
                if [[ -n "${GEM_PROVIDERS[${args}]+set}" ]]; then
                    GEM_AGENT_PROVIDER="${args}"
                    GEM_PROVIDER="${args}"
                    gem_chat_color_system "Provider set to: ${args}"
                else
                    gem_chat_color_error "Unknown provider: ${args}"
                    gem_provider_list
                fi
            else
                printf "Current provider: %s (%s)\n" "${GEM_AGENT_PROVIDER}" "${GEM_PROVIDERS[${GEM_AGENT_PROVIDER}]}"
                printf "\n"
                gem_provider_list
            fi
            ;;

        /system)
            if [[ -n "${args}" ]]; then
                GEM_AGENT_SYSTEM_PROMPT="${args}"
                gem_chat_color_system "System prompt updated"
            else
                printf "System prompt: %s\n" "${GEM_AGENT_SYSTEM_PROMPT}"
            fi
            ;;

        /clear)
            gem_history_clear "${GEM_CHAT_SESSION}"
            gem_chat_color_system "Conversation cleared"
            ;;

        /history)
            local count
            count="$(gem_history_count "${GEM_CHAT_SESSION}")"
            printf "Conversation history (%d messages):\n" "${count}"
            gem_history_export_markdown "${GEM_CHAT_SESSION}"
            ;;

        /export)
            local outfile="${args:-gem-export-$(date +%Y%m%d-%H%M%S).md}"
            gem_history_export_markdown "${GEM_CHAT_SESSION}" "${outfile}"
            ;;

        /memory)
            if [[ -z "${args}" ]]; then
                printf "Memory entries:\n"
                gem_memory_list "${GEM_CHAT_SESSION}"
            else
                local key value
                key="$(printf '%s' "${args}" | awk '{print $1}')"
                value="$(printf '%s' "${args}" | sed 's/^[^[:space:]]*[[:space:]]*//')"
                if [[ -n "${value}" ]]; then
                    gem_memory_save "${GEM_CHAT_SESSION}" "${key}" "${value}"
                    gem_chat_color_system "Memory saved: ${key} = ${value}"
                else
                    local recalled
                    recalled="$(gem_memory_recall "${GEM_CHAT_SESSION}" "${key}")"
                    if [[ -n "${recalled}" ]]; then
                        printf "%s = %s\n" "${key}" "${recalled}"
                    else
                        gem_chat_color_dim "No memory found for: ${key}"
                    fi
                fi
            fi
            ;;

        /forget)
            if [[ -n "${args}" ]]; then
                gem_memory_delete "${GEM_CHAT_SESSION}" "${args}"
                gem_chat_color_system "Memory deleted: ${args}"
            else
                gem_chat_color_error "Usage: /forget <key>"
            fi
            ;;

        /tools)
            if [[ -z "${args}" ]]; then
                gem_tools_list
            elif [[ "${args}" == "on" ]]; then
                GEM_ENABLE_TOOLS=1
                gem_chat_color_system "Tools enabled"
            elif [[ "${args}" == "off" ]]; then
                GEM_ENABLE_TOOLS=0
                gem_chat_color_system "Tools disabled"
            else
                gem_chat_color_error "Usage: /tools [on|off]"
            fi
            ;;

        /multiline|/ml)
            GEM_CHAT_MULTILINE=$((1 - GEM_CHAT_MULTILINE))
            if [[ "${GEM_CHAT_MULTILINE}" -eq 1 ]]; then
                gem_chat_color_system "Multiline mode ON (enter empty line to submit)"
            else
                gem_chat_color_system "Multiline mode OFF"
            fi
            ;;

        /session)
            if [[ -n "${args}" ]]; then
                GEM_CHAT_SESSION="${args}"
                GEM_AGENT_SESSION="${args}"
                gem_history_init "${args}"
                gem_chat_color_system "Switched to session: ${args}"
            else
                printf "Sessions:\n"
                gem_history_list_sessions
            fi
            ;;

        /verbose)
            if [[ "${args}" == "on" ]]; then
                GEM_VERBOSE=1
                gem_chat_color_system "Verbose mode ON"
            elif [[ "${args}" == "off" ]]; then
                GEM_VERBOSE=0
                gem_chat_color_system "Verbose mode OFF"
            else
                GEM_VERBOSE=$((1 - GEM_VERBOSE))
                gem_chat_color_system "Verbose mode: $( [[ ${GEM_VERBOSE} -eq 1 ]] && echo ON || echo OFF )"
            fi
            ;;

        /save)
            gem_config_set "GEM_MODEL" "${GEM_AGENT_MODEL}"
            gem_config_set "GEM_PROVIDER" "${GEM_AGENT_PROVIDER}"
            gem_chat_color_system "Configuration saved"
            ;;

        /reset)
            gem_history_clear "${GEM_CHAT_SESSION}"
            GEM_AGENT_ITERATION=0
            GEM_AGENT_SESSION="${GEM_CHAT_SESSION}"
            gem_chat_color_system "Agent and conversation reset"
            ;;

        /quit|/exit|/q)
            GEM_CHAT_RUNNING=0
            gem_chat_color_dim "Goodbye!"
            ;;

        *)
            gem_chat_color_error "Unknown command: ${cmd}"
            gem_chat_color_dim "Type /help for available commands"
            ;;
    esac
}

# --- Chat REPL ---

# Print the chat banner
gem_chat_banner() {
    printf "\n"
    gem_chat_color_bold "  ╔══════════════════════════════╗"
    gem_chat_color_bold "  ║     💎 Gem CLI v${GEM_VERSION}      ║"
    gem_chat_color_bold "  ║     HintyCloud Project       ║"
    gem_chat_color_bold "  ╚══════════════════════════════╝"
    printf "\n"
    gem_chat_color_dim "  Model: ${GEM_AGENT_MODEL} | Provider: ${GEM_AGENT_PROVIDER}"
    gem_chat_color_dim "  Session: ${GEM_CHAT_SESSION} | Tools: $( [[ ${GEM_ENABLE_TOOLS:-1} -eq 1 ]] && echo ON || echo OFF )"
    gem_chat_color_dim "  Type /help for commands, /quit to exit"
    printf "\n"
}

# Print input prompt
gem_chat_prompt() {
    if [[ "${GEM_CHAT_MULTILINE}" -eq 1 ]]; then
        printf '...> '
    else
        printf 'gem> '
    fi
}

# Process user input
gem_chat_process_input() {
    local input="${1}"

    # Skip empty input
    if [[ -z "${input}" ]]; then
        return
    fi

    # Handle slash commands
    if [[ "${input}" =~ ^/ ]]; then
        gem_chat_slash_command "${input}"
        return
    fi

    # Send to agent
    printf "\n"
    gem_chat_color_assistant "Gem:"

    local rc
    if [[ "${GEM_ENABLE_STREAMING:-1}" == "1" ]]; then
        gem_agent_run_stream "${input}" "${GEM_CHAT_SESSION}" "${GEM_AGENT_MODEL}"
        rc=$?
    else
        gem_agent_run "${input}" "${GEM_CHAT_SESSION}" "${GEM_AGENT_MODEL}"
        rc=$?
    fi

    if [[ ${rc} -ne 0 ]]; then
        printf "\n"
        gem_chat_color_error "Error: Agent returned exit code ${rc}"
    fi

    printf "\n"

    # Trim history
    gem_history_trim "${GEM_CHAT_SESSION}"
}

# Main chat loop
gem_chat_repl() {
    local session="${1:-default}"
    local initial_message="${2:-}"

    GEM_CHAT_SESSION="${session}"
    GEM_CHAT_RUNNING=1

    # Initialize agent for this session
    gem_agent_init "${session}"

    # Show banner
    gem_chat_banner

    # Handle initial message (non-interactive mode)
    if [[ -n "${initial_message}" ]]; then
        gem_chat_process_input "${initial_message}"
        return
    fi

    # Set up readline if available
    if [[ -t 0 ]]; then
        # Configure readline for the session
        bind 'set disable-completion off' 2>/dev/null || true
        bind 'set show-all-if-ambiguous on' 2>/dev/null || true
    fi

    # Main REPL loop
    while [[ "${GEM_CHAT_RUNNING}" -eq 1 ]]; do
        gem_chat_prompt

        local line=""
        if [[ "${GEM_CHAT_MULTILINE}" -eq 1 ]]; then
            # Multiline mode: collect until empty line
            GEM_CHAT_MULTILINE_BUFFER=""
            while IFS= read -r line; do
                if [[ -z "${line}" ]]; then
                    break
                fi
                if [[ -n "${GEM_CHAT_MULTILINE_BUFFER}" ]]; then
                    GEM_CHAT_MULTILINE_BUFFER+=$'\n'"${line}"
                else
                    GEM_CHAT_MULTILINE_BUFFER="${line}"
                fi
                printf '...> '
            done
            line="${GEM_CHAT_MULTILINE_BUFFER}"
        else
            # Single line mode
            if ! IFS= read -r line; then
                # EOF (e.g., piped input ended)
                printf "\n"
                break
            fi
        fi

        # Process the input
        gem_chat_process_input "${line}"
    done
}

# --- Chat Utility Functions ---

# Send a single message without entering REPL
gem_chat_send() {
    local message="${1}"
    local session="${2:-default}"
    local model="${3:-${GEM_AGENT_MODEL}}"

    gem_agent_init "${session}"

    if [[ "${GEM_ENABLE_STREAMING:-1}" == "1" ]]; then
        gem_agent_run_stream "${message}" "${session}" "${model}"
    else
        gem_agent_run "${message}" "${session}" "${model}"
    fi
}

# Replay/resume a session
gem_chat_resume() {
    local session="${1:-default}"
    GEM_CHAT_SESSION="${session}"
    GEM_CHAT_RUNNING=1

    gem_agent_init "${session}"

    local count
    count="$(gem_history_count "${session}")"

    printf "Resuming session: %s (%d messages)\n\n" "${session}" "${count}"

    # Show last few messages for context
    if [[ "${count}" -gt 0 ]]; then
        local history
        history="$(gem_history_get_messages "${session}")"
        local show_count
        show_count=$((count < 6 ? count : 6))
        local start_idx=$((count - show_count))

        printf "Recent messages:\n"
        local i role content
        for ((i=start_idx; i<count; i++)); do
            role="$(printf '%s' "${history}" | jq -r ".[${i}].role" 2>/dev/null)"
            content="$(printf '%s' "${history}" | jq -r ".[${i}].content" 2>/dev/null)"
            # Truncate long content
            if [[ ${#content} -gt 100 ]]; then
                content="${content:0:100}..."
            fi
            case "${role}" in
                user)      printf "  You: %s\n" "${content}" ;;
                assistant) printf "  Gem: %s\n" "${content}" ;;
                system)    printf "  [system]: %s\n" "${content}" ;;
                tool)      printf "  [tool]: %s\n" "${content}" ;;
            esac
        done
        printf "\n"
    fi

    # Enter REPL
    gem_chat_banner
    while [[ "${GEM_CHAT_RUNNING}" -eq 1 ]]; do
        gem_chat_prompt
        local line
        if ! IFS= read -r line; then
            printf "\n"
            break
        fi
        gem_chat_process_input "${line}"
    done
}
