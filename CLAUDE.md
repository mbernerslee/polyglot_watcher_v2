# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PolyglotWatcherV2 is an Elixir file watcher that automatically runs tests when files change. It supports Elixir and Rust with multiple testing modes and AI-powered code fixing via the Anthropic API.

## Build & Development Commands

```bash
# Full build pipeline (checks TODOs, deps, compiles, runs tests, creates release)
./build

# Build and run
./build_and_run [args]

# Quick development build (skips full test suite)
./build_and_run_dirty

# Development run
./dev_run

# Run all tests
mix test

# Run specific test file
mix test test/elixir/determiner_test.exs

# Run specific test at line
mix test test/elixir/determiner_test.exs:42

# Compile with warnings-as-errors (used by build scripts)
MIX_ENV=test mix compile --warnings-as-errors --force

# Production release
MIX_ENV=prod mix release --overwrite
```

## Architecture

### Core Components

**Server (`lib/server.ex`)** - Main GenServer handling file system events and user input. Maintains `ServerState` with current mode, AI state, file patches, and cached environment variables.

**Action Tree Pattern** - Test runs are represented as action trees (`lib/structs.ex`). Each node contains a runnable (shell command, function, or no-op) and conditional next actions based on success/failure. Trees are traversed by `lib/traverse_actions_tree.ex`.

**Mode System** - Each language has modes determining behavior on file save:
- Elixir modes in `lib/elixir/` (default, run_all, fixed, fix_all, fix_all_for_file, ai/replace_mode)
- Rust modes in `lib/rust/` (default, test)
- Determiners (`lib/elixir/determiner.ex`, `lib/rust/determiner.ex`) map file changes to action trees

**File Watching** - Platform-specific watchers in `lib/file_system_watchers/`:
- `fswatch.ex` for macOS (requires fswatch via brew)
- `inotifywait.ex` for Linux (requires inotify-tools)
- Common interface via `behaviour.ex`

### AI Integration

AI code fixing uses the Anthropic API via InstructorLite for structured responses:
- `lib/ai/ai.ex` - API requests, prompt loading, response processing
- Prompts stored in `~/.config/polyglot_watcher_v2/prompts/`
- Response parsed into `CodeFileUpdates` schema with find/replace blocks
- `lib/file_patches.ex` applies patches to files

### Dependency Injection

Production vs test behavior is controlled via Application config:
- `ActionsExecutor` - real shell execution vs fake for tests
- `FileSystem.FileWrapper` - real file I/O vs fake
- `InstructorLiteWrapper` - real API calls vs fake

## Testing

Tests use ExUnit with Mimic for mocking. Test config (`config/test.exs`) swaps real modules for fakes.

Key mocked modules: `ShellCommandRunner`, `FileSystem.FileWrapper`, `Puts`, `SystemWrapper`, `ActionsExecutor`, `Elixir.Cache`, `InstructorLiteWrapper`, `OSWrapper`

Test files mirror the lib structure in `/test`.

## User Commands (Runtime)

When the app is running, users enter commands to switch modes:
- `ex d` - Elixir default mode (run equivalent test)
- `ex ra` - Run all tests on any save
- `ex f [path]` - Run specific test file
- `ex fa` - Fix all mode (run all, fix failures individually)
- `ex faff [path]` - Fix all for file mode
- `ex air` - AI replace mode (default + AI fixing)
- `rs d` - Rust default (cargo build)
- `rs t` - Rust test (cargo test)

## Configuration

User config at `~/.config/polyglot_watcher_v2/config.yml`:
```yaml
AI:
  vendor: Anthropic
  model: claude-3-5-sonnet-20240620
```

## Key Data Structures

`ServerState` - Main GenServer state containing port, current modes, AI state, file patches, config

`Action` - Tree node with runnable and conditional next actions (`run_if_successful`, `run_if_failed`)

`FilePatch` - Find/replace operation with explanation from AI

## Dependencies

- Elixir 1.18.3+ / Erlang/OTP 27+
- fswatch (macOS) or inotify-tools (Linux)
- Key libs: jason, req, yaml_elixir, instructor_lite, mimic (test)
