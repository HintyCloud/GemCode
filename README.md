A coding agent for your terminal.

""Rust" (https://img.shields.io/badge/built%20with-Rust-orange?logo=rust&logoColor=white)" (https://www.rust-lang.org/)


""License" (https://img.shields.io/badge/license-GPL--3.0-blue.svg)" (LICENSE)



""Platform" (https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20Termux-lightgrey)" (#platforms)


""GitHub" (https://img.shields.io/badge/GitHub-HintyCloud%2Fgem--rust-black?logo=github)" (https://github.com/HintyCloud/gem-rust)

Gem is a coding agent for developers who want to work with their codebase directly from the command line.

It can read and edit files, run commands, work with Git, search the web, manage artifacts, and handle development tasks without leaving the terminal.

$ gem

> Fix the failing tests

That's the idea behind Gem: keep the workflow in your terminal, while giving you an agent that can work with the project instead of only talking about it.

Features

- Terminal-first workflow
- Codebase-aware agent
- File reading and editing
- Shell command execution
- Git integration
- Web search
- Image tools
- Archive tools
- Artifact management
- Multiple providers and models
- Persistent sessions
- Background jobs
- Multi-agent execution
- HTTP/WebSocket server
- Linux, macOS, Windows and Termux support

---

Installation

Gem is currently installed from source using Cargo.

git clone https://github.com/HintyCloud/gem-rust.git
cd gem-rust

cargo install --path .

Check the installation:

gem --help

If the command prints the help output, Gem is ready to use.

---

Usage

Start Gem inside a project:

gem

Or start a chat directly:

gem chat

Once the session starts, describe the task normally:

> Explain how authentication works

> Refactor this function

> Add tests for this module

> Review my current git diff

> Find and fix the bug in this project

Gem can inspect the project, decide which tools are needed, make changes, and run commands as part of the same task.

You don't need to manually move between a chat window, terminal, and file editor for every step.

:)

---

Tools

Gem provides tools for common development tasks.

gem tools list

Tool| Description
"shell"| Run commands
"files"| Read and edit files
"git"| Work with Git
"web_search"| Search the web
"image"| Image tools
"archive"| Archive files
"artifacts"| Manage artifacts

Tools can be combined during a single task.

For example, when asked to fix a failing test, Gem may inspect the relevant files, run the test suite, read the output, modify the implementation, and run the tests again.

---

Providers and Models

Gem isn't tied to a single provider.

""Providers" (https://img.shields.io/badge/providers-multiple-7c3aed)" (#providers-and-models)
""Models" (https://img.shields.io/badge/models-selectable-2563eb)" (#providers-and-models)

List available providers:

gem providers

List available models:

gem models

Start a chat using a specific provider and model:

gem chat --provider <provider> --model <model>

Keeping providers and models separate from the agent itself makes it possible to use different backends without changing the rest of the workflow.

---

Sessions

Gem supports persistent sessions, so longer development tasks don't have to start from scratch every time.

/new
/chats
/history
/status
/memory

"/new"

Start a new conversation.

"/chats"

List previous chats.

"/history"

View conversation history.

"/status"

Show the current session status.

"/memory"

Access Gem's memory functionality.

A typical session can grow with the project:

> Analyze the authentication system

> Find the main token validation code

> Refactor it

> Now add tests

> Review the changes

The session can be continued as the work progresses.

---

Jobs

Some operations take longer than a normal interaction.

Gem supports background jobs for things such as builds, test suites, and other long-running commands.

""Background Jobs" (https://img.shields.io/badge/background_jobs-supported-16a34a)" (#jobs)

Check running and completed jobs with:

/jobs

For example:

> Run the complete test suite in the background

Then:

/jobs

This is useful when you want to keep working while a longer operation is running.

---

Multi-Agent

Gem can run multiple agents when a task benefits from multiple perspectives or independent pieces of work.

""Multi-Agent" (https://img.shields.io/badge/multi--agent-supported-9333ea)" (#multi-agent)

Available modes:

Sequential

Agent A → Agent B → Agent C

Agents work one after another.

Parallel

          ┌─ Agent A
Task ─────┼─ Agent B
          └─ Agent C

Agents can work on different parts of a task at the same time.

Supervisor

          Supervisor
         /     |     \
     Agent A Agent B Agent C

A supervisor coordinates the other agents and delegates work.

Round-Robin

Agent A → Agent B → Agent C → Agent A

Agents take turns working on the task.

---

Server

Gem can also run as a server:

gem serve

""HTTP" (https://img.shields.io/badge/API-HTTP-0f766e)" (#server)
""WebSocket" (https://img.shields.io/badge/API-WebSocket-0f766e)" (#server)

Server mode exposes Gem through HTTP/WebSocket APIs.

This allows other applications and clients to communicate with the agent without using the CLI directly.

---

Platforms

""Linux" (https://img.shields.io/badge/Linux-supported-111827?logo=linux&logoColor=white)" (#platforms)
""macOS" (https://img.shields.io/badge/macOS-supported-111827?logo=apple&logoColor=white)" (#platforms)
""Windows" (https://img.shields.io/badge/Windows-supported-111827?logo=windows&logoColor=white)" (#platforms)
""Termux" (https://img.shields.io/badge/Termux-supported-111827)" (#platforms)

Gem currently targets:

- Linux
- macOS
- Windows
- Termux

---

Development

Clone the repository:

git clone https://github.com/HintyCloud/gem-rust.git
cd gem-rust

Run Gem locally:

cargo run

Build

cargo build

For a release build:

cargo build --release

Test

cargo test

""Tests" (https://img.shields.io/badge/tests-cargo%20test-16a34a)" (#development)

Format

cargo fmt

Check

cargo check

Clippy

cargo clippy

Before opening a pull request, run:

cargo fmt
cargo check
cargo test
cargo clippy

---

Architecture

At a high level, Gem is built around an agent runtime that connects models and providers with the tools available in the environment.

                         Gem
                          │
                          ▼
                    ┌───────────┐
                    │    CLI    │
                    └─────┬─────┘
                          │
                          ▼
                  ┌───────────────┐
                  │ Agent Runtime │
                  └───────┬───────┘
                          │
            ┌─────────────┼─────────────┐
            │             │             │
        Providers      Sessions        Jobs
            │             │             │
            └─────────────┼─────────────┘
                          │
                          ▼
                       Tools
                          │
          ┌───────────────┼───────────────┐
          │               │               │
        Files           Shell            Git
          │               │               │
     Web Search        Images        Artifacts

The agent runtime handles the interaction between the model and the tools.

Providers and models remain separate so the underlying model can change without changing the rest of the application.

---

Security

""Security" (https://img.shields.io/badge/security-in%20development-f59e0b)" (#security)

Gem can read and modify files and execute commands in the environment where it is running.

Because of that, you should treat Gem as a tool with access to your development environment.

Be careful when running it in:

- production environments
- repositories containing secrets
- environments with sensitive credentials
- systems with access to external services
- directories where destructive commands could cause problems

Review changes before committing or deploying them.

Better tool permissions and sandboxing are part of the roadmap.

---

Roadmap

- [ ] Better tool permissions
- [ ] More providers
- [ ] Plugin system
- [ ] Better sandboxing
- [ ] Improved context handling
- [ ] More multi-agent modes
- [ ] Web UI
- [ ] Remote execution

The roadmap may change as the project develops.

---

Contributing

Issues and pull requests are welcome.

""Contributions Welcome" (https://img.shields.io/badge/contributions-welcome-2563eb)" (#contributing)

For code changes, make sure the project passes the standard checks:

cargo fmt
cargo check
cargo test
cargo clippy

For new features, add tests where appropriate and update the documentation when user-facing behavior changes.

When reporting a bug, include:

- Operating system
- Gem version or commit
- Command used
- Relevant output
- Steps to reproduce
- Expected behavior
- Actual behavior

---

License

""License" (https://img.shields.io/badge/license-GPL--3.0-blue)" (LICENSE)

Gem is licensed under the GNU General Public License v3.0.

See "LICENSE" (LICENSE) for the complete license text.

---

Gem is built to stay close to the way developers already work.

Open the terminal, start Gem, and get to work.

:D
