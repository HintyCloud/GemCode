#!/usr/bin/env bash
# lib/tools.sh - Tool functions for Gem CLI
# Copyright (C) 2025 HintyCloud - GPL-3.0

# Tool registry (Bash 4+ associative arrays)
declare -gA GEM_TOOLS=()
declare -gA GEM_TOOL_DESC=()

# --- Tool Registration ---

gem_tool_register() {
    local name="${1}"
    local desc="${2}"
    GEM_TOOLS["${name}"]="gem_tool_exec_${name}"
    GEM_TOOL_DESC["${name}"]="${desc}"
}

gem_tool_register_builtins() {
    gem_tool_register "shell"       "Execute shell commands"
    gem_tool_register "files"       "Read, write, and manage files"
    gem_tool_register "web_search"  "Search the web for information"
    gem_tool_register "image"       "Generate and analyze images"
    gem_tool_register "git"         "Git version control operations"
    gem_tool_register "archive"     "Create and extract archives"
    gem_tool_register "artifacts"   "Manage code artifacts and snippets"
}

# --- Tool Schema Generation (OpenAI function format) ---

gem_tool_schema_shell() {
    jq -n '{
        type: "function",
        function: {
            name: "shell",
            description: "Execute a shell command and return its output",
            parameters: {
                type: "object",
                properties: {
                    command: {
                        type: "string",
                        description: "The shell command to execute"
                    },
                    cwd: {
                        type: "string",
                        description: "Working directory (optional)"
                    }
                },
                required: ["command"]
            }
        }
    }'
}

gem_tool_schema_files() {
    jq -n '{
        type: "function",
        function: {
            name: "files",
            description: "Read, write, list, or search files",
            parameters: {
                type: "object",
                properties: {
                    action: {
                        type: "string",
                        enum: ["read", "write", "list", "search", "delete", "mkdir"],
                        description: "The file operation to perform"
                    },
                    path: {
                        type: "string",
                        description: "File or directory path"
                    },
                    content: {
                        type: "string",
                        description: "Content to write (for write action)"
                    },
                    pattern: {
                        type: "string",
                        description: "Search pattern (for search action)"
                    }
                },
                required: ["action", "path"]
            }
        }
    }'
}

gem_tool_schema_web_search() {
    jq -n '{
        type: "function",
        function: {
            name: "web_search",
            description: "Search the web for information using a search engine",
            parameters: {
                type: "object",
                properties: {
                    query: {
                        type: "string",
                        description: "The search query"
                    },
                    count: {
                        type: "integer",
                        description: "Number of results to return (default: 5)"
                    }
                },
                required: ["query"]
            }
        }
    }'
}

gem_tool_schema_image() {
    jq -n '{
        type: "function",
        function: {
            name: "image",
            description: "Generate or analyze images",
            parameters: {
                type: "object",
                properties: {
                    action: {
                        type: "string",
                        enum: ["generate", "analyze", "describe"],
                        description: "Image operation"
                    },
                    prompt: {
                        type: "string",
                        description: "Description or prompt for the image"
                    },
                    path: {
                        type: "string",
                        description: "Path to image file (for analyze/describe)"
                    },
                    size: {
                        type: "string",
                        enum: ["256x256", "512x512", "1024x1024"],
                        description: "Image size for generation"
                    }
                },
                required: ["action"]
            }
        }
    }'
}

gem_tool_schema_git() {
    jq -n '{
        type: "function",
        function: {
            name: "git",
            description: "Perform git version control operations",
            parameters: {
                type: "object",
                properties: {
                    action: {
                        type: "string",
                        enum: ["status", "log", "diff", "add", "commit", "push", "pull", "branch", "checkout"],
                        description: "Git operation to perform"
                    },
                    args: {
                        type: "string",
                        description: "Additional arguments for the git command"
                    }
                },
                required: ["action"]
            }
        }
    }'
}

gem_tool_schema_archive() {
    jq -n '{
        type: "function",
        function: {
            name: "archive",
            description: "Create or extract archives (tar, zip)",
            parameters: {
                type: "object",
                properties: {
                    action: {
                        type: "string",
                        enum: ["create", "extract", "list"],
                        description: "Archive operation"
                    },
                    path: {
                        type: "string",
                        description: "Archive file path"
                    },
                    source: {
                        type: "string",
                        description: "Source files/directory (for create)"
                    },
                    format: {
                        type: "string",
                        enum: ["tar.gz", "tar.bz2", "tar.xz", "zip"],
                        description: "Archive format"
                    }
                },
                required: ["action", "path"]
            }
        }
    }'
}

gem_tool_schema_artifacts() {
    jq -n '{
        type: "function",
        function: {
            name: "artifacts",
            description: "Manage code artifacts and snippets",
            parameters: {
                type: "object",
                properties: {
                    action: {
                        type: "string",
                        enum: ["save", "load", "list", "delete", "run"],
                        description: "Artifact operation"
                    },
                    name: {
                        type: "string",
                        description: "Artifact name/identifier"
                    },
                    content: {
                        type: "string",
                        description: "Artifact content (for save)"
                    },
                    language: {
                        type: "string",
                        description: "Programming language for syntax highlighting"
                    }
                },
                required: ["action", "name"]
            }
        }
    }'
}

# Build the complete tools JSON array for API requests
gem_tools_build_schema() {
    local schemas=()

    schemas+=("$(gem_tool_schema_shell)")
    schemas+=("$(gem_tool_schema_files)")
    schemas+=("$(gem_tool_schema_web_search)")
    schemas+=("$(gem_tool_schema_image)")
    schemas+=("$(gem_tool_schema_git)")
    schemas+=("$(gem_tool_schema_archive)")
    schemas+=("$(gem_tool_schema_artifacts)")

    # Combine into JSON array
    local result="["
    local first=true
    local schema
    for schema in "${schemas[@]}"; do
        if [[ "${first}" == "true" ]]; then
            result+="${schema}"
            first=false
        else
            result+=",${schema}"
        fi
    done
    result+="]"

    printf '%s' "${result}"
}

# --- Tool Execution ---

# Execute shell command
gem_tool_exec_shell() {
    local args="${1}"
    local command
    command="$(printf '%s' "${args}" | jq -r '.command // empty')"
    local cwd
    cwd="$(printf '%s' "${args}" | jq -r '.cwd // empty')"

    if [[ -z "${command}" ]]; then
        printf '{"error":"missing required parameter: command"}'
        return 1
    fi

    # Security: block dangerous commands
    local blocked_cmds=("rm -rf /" "mkfs" "dd if=" ":(){:|:&};:")
    local bc
    for bc in "${blocked_cmds[@]}"; do
        if [[ "${command}" == *"${bc}"* ]]; then
            printf '{"error":"command blocked for safety"}'
            return 1
        fi
    done

    local output rc
    if [[ -n "${cwd}" ]] && [[ -d "${cwd}" ]]; then
        output="$(cd "${cwd}" && eval "${command}" 2>&1)"
        rc=$?
    else
        output="$(eval "${command}" 2>&1)"
        rc=$?
    fi

    # Truncate very long output
    if [[ ${#output} -gt 10000 ]]; then
        output="${output:0:10000}... [truncated]"
    fi

    jq -n --arg output "${output}" --argjson rc "${rc}" \
        '{output: $output, exit_code: $rc}'
}

# Execute file operation
gem_tool_exec_files() {
    local args="${1}"
    local action
    action="$(printf '%s' "${args}" | jq -r '.action // empty')"
    local path
    path="$(printf '%s' "${args}" | jq -r '.path // empty')"
    local content
    content="$(printf '%s' "${args}" | jq -r '.content // empty')"
    local pattern
    pattern="$(printf '%s' "${args}" | jq -r '.pattern // empty')"

    case "${action}" in
        read)
            if [[ -f "${path}" ]]; then
                local fcontent
                fcontent="$(cat "${path}" 2>/dev/null | head -c 10000)"
                jq -n --arg content "${fcontent}" '{content: $content}'
            else
                printf '{"error":"file not found: %s"}' "${path}"
            fi
            ;;
        write)
            mkdir -p "$(dirname "${path}")" 2>/dev/null
            printf '%s' "${content}" > "${path}" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                printf '{"result":"written to %s"}' "${path}"
            else
                printf '{"error":"failed to write to %s"}' "${path}"
            fi
            ;;
        list)
            if [[ -d "${path}" ]]; then
                local entries
                entries="$(ls -1a "${path}" 2>/dev/null | head -100)"
                jq -n --arg entries "${entries}" '{entries: $entries}'
            else
                printf '{"error":"directory not found: %s"}' "${path}"
            fi
            ;;
        search)
            if [[ -n "${pattern}" ]]; then
                local results
                results="$(rg -l "${pattern}" "${path}" 2>/dev/null | head -20 || find "${path}" -name "*${pattern}*" -maxdepth 3 2>/dev/null | head -20)"
                jq -n --arg results "${results}" '{results: $results}'
            else
                printf '{"error":"pattern required for search"}'
            fi
            ;;
        delete)
            if [[ -f "${path}" ]] || [[ -d "${path}" ]]; then
                rm -rf "${path}" 2>/dev/null
                printf '{"result":"deleted: %s"}' "${path}"
            else
                printf '{"error":"not found: %s"}' "${path}"
            fi
            ;;
        mkdir)
            mkdir -p "${path}" 2>/dev/null
            printf '{"result":"created directory: %s"}' "${path}"
            ;;
        *)
            printf '{"error":"unknown action: %s"}' "${action}"
            ;;
    esac
}

# Execute web search
gem_tool_exec_web_search() {
    local args="${1}"
    local query
    query="$(printf '%s' "${args}" | jq -r '.query // empty')"
    local count
    count="$(printf '%s' "${args}" | jq -r '.count // 5')"

    if [[ -z "${query}" ]]; then
        printf '{"error":"missing required parameter: query"}'
        return 1
    fi

    # Use DuckDuckGo Lite as a simple search backend
    local encoded_query
    encoded_query="$(printf '%s' "${query}" | jq -sRr @uri)"
    local response
    response="$(curl -s -L "https://lite.duckduckgo.com/lite?q=${encoded_query}" 2>/dev/null)"

    # Extract results (basic HTML parsing)
    local results=""
    if [[ -n "${response}" ]]; then
        # Try to extract link snippets
        results="$(printf '%s' "${response}" | grep -oP 'href="[^"]*"' | head -n "${count}" | sed 's/href="//;s/"$//' | grep -v 'duckduckgo\|javascript\|#' 2>/dev/null)"
    fi

    if [[ -n "${results}" ]]; then
        jq -n --arg results "${results}" '{results: $results}'
    else
        printf '{"results":"No results found for query: %s"}' "${query}"
    fi
}

# Execute image tool
gem_tool_exec_image() {
    local args="${1}"
    local action
    action="$(printf '%s' "${args}" | jq -r '.action // empty')"
    local prompt
    prompt="$(printf '%s' "${args}" | jq -r '.prompt // empty')"

    case "${action}" in
        generate)
            if [[ -z "${prompt}" ]]; then
                printf '{"error":"prompt required for image generation"}'
                return 1
            fi
            # Stub: would call image generation API
            printf '{"result":"Image generation requested: %s (stub - configure image API endpoint)"}' "${prompt}"
            ;;
        analyze|describe)
            printf '{"result":"Image analysis stub - configure vision API endpoint"}'
            ;;
        *)
            printf '{"error":"unknown action: %s"}' "${action}"
            ;;
    esac
}

# Execute git tool
gem_tool_exec_git() {
    local args="${1}"
    local action
    action="$(printf '%s' "${args}" | jq -r '.action // empty')"
    local extra_args
    extra_args="$(printf '%s' "${args}" | jq -r '.args // empty')"

    if ! command -v git &>/dev/null; then
        printf '{"error":"git is not installed"}'
        return 1
    fi

    local output rc
    case "${action}" in
        status|log|diff|add|commit|push|pull|branch|checkout)
            if [[ -n "${extra_args}" ]]; then
                output="$(git ${action} ${extra_args} 2>&1)"
            else
                output="$(git ${action} 2>&1)"
            fi
            rc=$?
            ;;
        *)
            printf '{"error":"unknown git action: %s"}' "${action}"
            return 1
            ;;
    esac

    if [[ ${#output} -gt 10000 ]]; then
        output="${output:0:10000}... [truncated]"
    fi

    jq -n --arg output "${output}" --argjson rc "${rc}" \
        '{output: $output, exit_code: $rc}'
}

# Execute archive tool
gem_tool_exec_archive() {
    local args="${1}"
    local action
    action="$(printf '%s' "${args}" | jq -r '.action // empty')"
    local path
    path="$(printf '%s' "${args}" | jq -r '.path // empty')"
    local source
    source="$(printf '%s' "${args}" | jq -r '.source // empty')"
    local format
    format="$(printf '%s' "${args}" | jq -r '.format // "tar.gz"')"

    case "${action}" in
        create)
            case "${format}" in
                tar.gz)  tar -czf "${path}" -C "$(dirname "${source}")" "$(basename "${source}")" 2>&1 ;;
                tar.bz2) tar -cjf "${path}" -C "$(dirname "${source}")" "$(basename "${source}")" 2>&1 ;;
                tar.xz)  tar -cJf "${path}" -C "$(dirname "${source}")" "$(basename "${source}")" 2>&1 ;;
                zip)     zip -r "${path}" "${source}" 2>&1 ;;
                *)       printf '{"error":"unsupported format: %s"}' "${format}"; return 1 ;;
            esac
            printf '{"result":"archive created: %s"}' "${path}"
            ;;
        extract)
            case "${path}" in
                *.tar.gz|*.tgz)  tar -xzf "${path}" 2>&1 ;;
                *.tar.bz2)       tar -xjf "${path}" 2>&1 ;;
                *.tar.xz)        tar -xJf "${path}" 2>&1 ;;
                *.zip)           unzip "${path}" 2>&1 ;;
                *)               printf '{"error":"cannot determine archive format from extension"}'; return 1 ;;
            esac
            printf '{"result":"archive extracted: %s"}' "${path}"
            ;;
        list)
            case "${path}" in
                *.tar.gz|*.tgz)  tar -tzf "${path}" 2>&1 ;;
                *.tar.bz2)       tar -tjf "${path}" 2>&1 ;;
                *.tar.xz)        tar -tJf "${path}" 2>&1 ;;
                *.zip)           unzip -l "${path}" 2>&1 ;;
                *)
                    local output
                    output="$(file "${path}" 2>&1)"
                    jq -n --arg output "${output}" '{info: $output}'
                    return 0
                    ;;
            esac
            ;;
        *)
            printf '{"error":"unknown action: %s"}' "${action}"
            ;;
    esac
}

# Execute artifacts tool
gem_tool_exec_artifacts() {
    local args="${1}"
    local action
    action="$(printf '%s' "${args}" | jq -r '.action // empty')"
    local name
    name="$(printf '%s' "${args}" | jq -r '.name // empty')"
    local content
    content="$(printf '%s' "${args}" | jq -r '.content // empty')"
    local language
    language="$(printf '%s' "${args}" | jq -r '.language // "text"')"

    local artifact_dir="${GEM_DATA_DIR}/artifacts"
    mkdir -p "${artifact_dir}" 2>/dev/null

    case "${action}" in
        save)
            printf '%s' "${content}" > "${artifact_dir}/${name}"
            printf '{"result":"artifact saved: %s"}' "${name}"
            ;;
        load)
            if [[ -f "${artifact_dir}/${name}" ]]; then
                local fcontent
                fcontent="$(cat "${artifact_dir}/${name}" 2>/dev/null)"
                jq -n --arg content "${fcontent}" --arg name "${name}" '{name: $name, content: $content}'
            else
                printf '{"error":"artifact not found: %s"}' "${name}"
            fi
            ;;
        list)
            local entries=""
            if [[ -d "${artifact_dir}" ]]; then
                entries="$(ls -1a "${artifact_dir}" 2>/dev/null | grep -v '^\.$\|^\.\.$')"
            fi
            jq -n --arg entries "${entries}" '{artifacts: $entries}'
            ;;
        delete)
            rm -f "${artifact_dir}/${name}" 2>/dev/null
            printf '{"result":"artifact deleted: %s"}' "${name}"
            ;;
        run)
            if [[ -f "${artifact_dir}/${name}" ]]; then
                local output
                output="$(bash "${artifact_dir}/${name}" 2>&1)"
                local rc=$?
                jq -n --arg output "${output}" --argjson rc "${rc}" '{output: $output, exit_code: $rc}'
            else
                printf '{"error":"artifact not found: %s"}' "${name}"
            fi
            ;;
        *)
            printf '{"error":"unknown action: %s"}' "${action}"
            ;;
    esac
}

# --- Tool Dispatch ---

# Execute a tool call by name
gem_tool_execute() {
    local tool_name="${1}"
    local tool_args="${2:-{}}"

    case "${tool_name}" in
        shell)       gem_tool_exec_shell "${tool_args}"       ;;
        files)       gem_tool_exec_files "${tool_args}"       ;;
        web_search)  gem_tool_exec_web_search "${tool_args}"  ;;
        image)       gem_tool_exec_image "${tool_args}"       ;;
        git)         gem_tool_exec_git "${tool_args}"         ;;
        archive)     gem_tool_exec_archive "${tool_args}"     ;;
        artifacts)   gem_tool_exec_artifacts "${tool_args}"   ;;
        *)
            printf '{"error":"unknown tool: %s"}' "${tool_name}"
            return 1
            ;;
    esac
}

# Process tool_calls from API response
gem_tool_process_calls() {
    local tool_calls="${1}"  # JSON array of tool_call objects
    local session="${2:-default}"
    local results=()
    local count
    count="$(printf '%s' "${tool_calls}" | jq 'length' 2>/dev/null)"

    local i
    for ((i=0; i<count; i++)); do
        local tc
        tc="$(printf '%s' "${tool_calls}" | jq -c ".[${i}]")"
        local call_id
        call_id="$(printf '%s' "${tc}" | jq -r '.id // "call_0"')"
        local func_name
        func_name="$(printf '%s' "${tc}" | jq -r '.function.name')"
        local func_args
        func_args="$(printf '%s' "${tc}" | jq -c '.function.arguments // {}')"

        # Display tool call
        printf "\n  🔧 Tool: %s\n" "${func_name}"
        if [[ "${GEM_VERBOSE:-0}" == "1" ]]; then
            printf "  Args: %s\n" "${func_args}"
        fi

        # Execute the tool
        local result
        result="$(gem_tool_execute "${func_name}" "${func_args}")"
        local rc=$?

        if [[ ${rc} -ne 0 ]]; then
            printf "  ❌ Error executing %s\n" "${func_name}"
        else
            printf "  ✅ Done\n"
        fi

        # Build tool result message
        local tool_result
        tool_result="$(jq -n \
            --arg call_id "${call_id}" \
            --arg func_name "${func_name}" \
            --arg result "${result}" \
            '{
                tool_call_id: $call_id,
                role: "tool",
                name: $func_name,
                content: $result
            }')"

        results+=("${tool_result}")

        # Save to history
        gem_history_append "${session}" "tool" "${result}"
    done

    # Return results as JSON array
    local json_results="["
    local first=true
    local r
    for r in "${results[@]}"; do
        if [[ "${first}" == "true" ]]; then
            json_results+="${r}"
            first=false
        else
            json_results+=",${r}"
        fi
    done
    json_results+="]"

    printf '%s' "${json_results}"
}

# List all available tools
gem_tools_list() {
    printf "Available Tools\n"
    printf "===============\n\n"
    local t
    for t in "${!GEM_TOOLS[@]}"; do
        printf "  %-15s %s\n" "${t}" "${GEM_TOOL_DESC[${t}]}"
    done
}

# Initialize tools
gem_tools_init() {
    gem_tool_register_builtins
}
