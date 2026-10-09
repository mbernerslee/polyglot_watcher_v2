<!-- Keep this up to date with the output of help -->
# PolyglotWatcherV2

A software development tool that triggers test runs when files are saved, using a number of different user-specified modes.
See the section 'Watcher usage and modes' below.

It also exposes an MCP server so that AI coding assistants (e.g. Claude Code) can run tests through the watcher. See the 'MCP Server' section below.

## Installation

### Prerequisites
- [Elixir](https://elixir-lang.org/) >= 1.18 - Probably works with somewhat lower versions, but not for sure
- [Erlang / OTP 27](https://www.erlang.org/)
- It's highly recommended to install both with [ASDF](https://asdf-vm.com/guide/getting-started.html)

Once you have the Prerequisites, if you're on Debian or Mac simply do:

- `git clone git@github.com:mbernerslee/polyglot_watcher_v2.git`
- `cd polyglot_watcher_v2`
- `./install`
- - The install script makes some assumptions about what you have in your PATH. It will fail if it adds its symlink to a directory that in fact is not in your PATH. You're on your own to fix it if that happens
- now you can run `polyglot_watcher_v2` from anywhere


...if you're on a different OS you'll have to look at how the `install` script works and figure out how to install it yourself. It shouldn't be too hard (unless you're on windows, in which case good luck to you).


## Watcher usage and modes

I can...

- switch which watcher mode I'm using the fly while I'm running
- initialise in the desired mode by passing in command line arguments

using the switches listed below...


### Elixir

| Mode | Switch | Description |
| ---- | ------ | ----------- |
| Default | `ex d` | Will run the equivalently pathed test only...<br /> In other words: <br /> `mix test/x_test.exs` <br /> when these files are saved: <br/> - lib/x.ex<br /> - test/x_test.exs <br /> |
| Run All | `ex ra` | Runs `mix test` whenever any .ex or .exs file is saved |
| Fixed | `ex f [path]` | Runs `mix test [path]` whenever any *.ex* or *.exs* file is saved. <br /> You can specify an exact line number e.g. `polyglot_watcher_v2 ex f test/cool_test.exs:100`, if you want. <br /><br /> OR without specifying `[path]` <br /><br /> Runs `mix test [the most recent failure in memory]` <br/> Initialising without specifying a path obviously doesn't really work because I'll have no memory of any test failures yet. |
| Fix All | `ex fa` | Runs <br /><br /> 1. `mix test` <br /> 2. `mix test [single test only]` for each failing test in turn, until they're all fixed. Then we run 1. again to check we really are done |
| Fix All For File | `ex faff [path]` | Runs <br /><br /> 1. `mix test [path]` <br /> 2. `mix test [path]:[one test line number only]` for each failing test in turn, until they're all fixed. Then we run 1. again to check we really are done <br /><br /> OR without specifying `[path]` <br /><br /> Runs the above but using the most recently failed test file from memory |
| AI Replace | `ex air` | The same as elixir default mode, but uses automatically fires an API call to an AI asing for find/replace suggestion codeblocks to fix the test. Read more below for details |

### Rust

| Mode | Switch | Description |
| ---- | ------ | ----------- |
| Default | `rs d` | Will always run `cargo build` when any `.rs` file is saved |
| Test | `rs t` | Will always run `cargo test` when any `.rs` file is saved |

## MCP Server

The watcher runs an [MCP](https://modelcontextprotocol.io/) (Model Context Protocol) server on a dynamically assigned port. This lets AI coding assistants run tests through the watcher instead of invoking `mix test` directly.

### Why?

If your AI assistant runs `mix test` at the same time the watcher does (because you saved a file), you get two concurrent test processes with interleaved output. The MCP server avoids this — all test runs go through a global mutex in the watcher, so only one `mix test` runs at a time. If the same test is already running, the MCP caller waits and gets the result without a duplicate run.

### Setup for Claude Code

Add a `.mcp.json` to your project root (or use `~/.claude/.mcp.json` for global config):

```json
{
  "mcpServers": {
    "polyglot-watcher": {
      "type": "stdio",
      "command": "/path/to/polyglot_watcher_v2/mcp_stdio_proxy"
    }
  }
}
```

The `mcp_stdio_proxy` script bridges Claude Code's stdio-based MCP transport to the watcher's HTTP endpoint. If the watcher isn't running, the first tool call **starts it automatically** (see [Auto-starting the watcher](#auto-starting-the-watcher)), so you never need to start it by hand for Claude. Claude Code sees the MCP server as connected either way.

Add the following to `~/.claude/projects/<your-project-path>/CLAUDE.md` (the private, per-user project instruction file — not the repo's own `CLAUDE.md`):

```
**MANDATORY: Use the `mcp__polyglot-watcher__mix_test` MCP tool to run tests.** Never run `mix test` via Bash — the MCP tool deduplicates with the file watcher's test runs. This overrides any `mix test` commands listed in the repo's CLAUDE.md. The MCP tool accepts `test_path` (string) and `line_number` (integer) parameters.
```

Why this file and not the repo's `CLAUDE.md`? Your repo's `CLAUDE.md` likely already lists `mix test` in its commands section — that directly tells Claude to use Bash. A project-level override in `~/.claude/projects/` takes effect alongside the repo instructions and is private to your machine.

### Preventing Claude from running `mix test` directly

Add a deny rule to your project's `.claude/settings.local.json`:

```json
{
  "permissions": {
    "deny": ["Bash(mix test:*)"]
  }
}
```

Merge this with any existing settings in that file. This blocks Claude from running any `mix test` command via Bash.

This is safe to do even if the watcher isn't always running — the `mcp_stdio_proxy` starts the watcher on the first tool call. If the watcher *can't* be started (e.g. the release isn't built), tool calls fail with an error explaining why; tests are never run around the watcher. In that case fix the watcher or disable the MCP.

**Important:** Check that `Bash(mix test:*)` is not also in your `allow` list (it can accumulate there from past approvals). If it appears in both `allow` and `deny`, remove it from `allow`.

### Available tools

| Tool | Description |
| ---- | ----------- |
| `mix_test` | Runs `mix test` with optional `test_path` and `line_number` parameters. Returns JSON with `exit_code`, `output`, and `test_path`. |
| `mix_test_known_failures` | Returns failing tests from the watcher's in-memory cache of prior runs. Empty until tests have actually run in this watcher session. |

### Auto-starting the watcher

When a tool call arrives and no watcher is answering for the project, the proxy
starts one, waits for it to be ready (up to 30s), then forwards the call. The
response then carries a `watcher_note` saying so — the watcher's in-memory
failure cache starts empty after a (re)start.

- Only **tool calls** start a watcher. `initialize` / `ping` / `tools/list` are
  answered by the proxy itself, because Claude Code spawns the proxy for every
  session, Elixir project or not.
- No `mix.exs` in the working directory, a missing release, or a watcher that
  doesn't become ready → the tool call returns an error (with the tail of
  `.polyglot_watcher_v2/watcher.log`). Nothing falls back to running tests
  around the watcher.
- Concurrent sessions in the same project share one watcher (an atomic start
  lock stops two sessions spawning one each).

#### Idle shutdown of detached watchers

A watcher the proxy spawns **detached** (see below) shuts itself down after
**30 minutes** with no MCP tool calls and no file changes, so auto-started
watchers don't pile up across projects and worktrees. It never shuts down
mid-way through a test run, and the next tool call simply starts a new one.
Both events are logged to `.polyglot_watcher_v2/watcher.log`:

```
[idle-shutdown] enabled — this watcher will exit after 30 min with no MCP tool calls or file changes ...
[idle-shutdown] no MCP tool calls or file changes for 30 min — shutting down ...
```

Change the timeout with `POLYGLOT_WATCHER_IDLE_SHUTDOWN_MINUTES` in the proxy's
environment (forward it in `.mcp.json` like the variables below; fractions are
fine). Watchers started from the command line, or through
`POLYGLOT_WATCHER_SPAWN_CMD`, never idle-shutdown.

### Making AI-started watchers visible: `POLYGLOT_WATCHER_SPAWN_CMD`

By default, the proxy spawns the watcher **detached**, with output going to
`.polyglot_watcher_v2/watcher.log`. That works, but throws away half the point of
the watcher: a human watching tests run in real time.

If the `POLYGLOT_WATCHER_SPAWN_CMD` environment variable is set (in the proxy's
environment), the proxy starts the watcher through it instead. The contract:

- The value is a **command prefix**, `eval`'d with the watcher launcher path
  appended as a single shell-quoted argument:
  `$POLYGLOT_WATCHER_SPAWN_CMD /path/to/polyglot_watcher_v2`
- Exit `0` means "spawned" — the proxy then polls for readiness as usual.
- Non-zero exit means "couldn't" (e.g. not inside tmux) — the proxy falls back
  to the detached spawn, so this can never break test running.

This only affects watchers the proxy auto-starts. Running `polyglot_watcher_v2`
from the command line is completely unchanged.

A typical wrapper opens a tmux split beside the pane the AI is working in, so
the watcher runs in the foreground there — visible, still interactive (you can
click in and switch modes), and killed automatically when the window closes:

```bash
#!/usr/bin/env bash
# tmux-split-run: run "$@" in a vertical split (right third of the screen).
# -c "$PWD" keeps the caller's cwd (the project dir) — the watcher must run
# there, not in whatever directory the split pane would inherit.
[ -n "$TMUX" ] || exit 1
cmd=$(printf '%q ' "$@")
if [ -n "$TMUX_PANE" ]; then
  exec tmux split-window -d -h -l '33%' -c "$PWD" -t "$TMUX_PANE" "$cmd"
else
  exec tmux split-window -d -h -l '33%' -c "$PWD" "$cmd"
fi
```

**Important env-forwarding caveat for Claude Code:** stdio MCP servers do *not*
inherit your shell environment — they get a scrubbed env plus whatever is in the
server's `env` block. Forward the variables you need with `${VAR:-}` expansion
(which resolves against Claude Code's own environment) in `.mcp.json`:

```json
{
  "mcpServers": {
    "polyglot-watcher": {
      "type": "stdio",
      "command": "/path/to/polyglot_watcher_v2/mcp_stdio_proxy",
      "env": {
        "POLYGLOT_WATCHER_SPAWN_CMD": "${POLYGLOT_WATCHER_SPAWN_CMD:-}",
        "TMUX": "${TMUX:-}",
        "TMUX_PANE": "${TMUX_PANE:-}"
      }
    }
  }
}
```

`TMUX` and `TMUX_PANE` are only needed because the tmux-split wrapper above uses
them; a different spawn command needs whatever *it* needs forwarded.

## Elixir AI Replace Mode

Right now the only supported model is Claude (Anthropic). More to come soon

### Requirements

- `git` installed
- For Claude:
Have a valid `ANTHROPIC_API_KEY` environment variable on your system.
See [https://docs.anthropic.com/en/docs/welcome](https://docs.anthropic.com/en/docs/welcome)

### What it does

By default this mode will trigger the following on file save:

- determine the equivalent lib / test file depending on which was saved
- run `mix test <test_file>`
- if the test fails, it will make an API call an AI to ask it if it can fix the test

The prompt is generated for you, and it splices the lib file, test file and the output of the test run into it.

The response is requested as find/replace/explanation blocks, which are displayed in a `git diff` format, and may be accepted (written to file) or rejected.

### Custom prompt

The prompt comes from a file located at:
`~/.config/polyglot_watcher_v2/prompts/replace`

The following placeholders will get be replaced with the real thing at runtime:
- `$LIB_PATH_PLACEHOLDER`
- `$LIB_CONTENT_PLACEHOLDER`
- `$TEST_PATH_PLACEHOLDER`
- `$TEST_CONTENT_PLACEHOLDER`
- `$MIX_TEST_OUTPUT_PLACEHOLDER`

Meaning that if you edit the prompt like this:

```
Given the lib file at $LIB_PATH_PLACEHOLDER with the contents:
$LIB_CONTENT_PLACEHOLDER

and the test file at $TEST_PATH_PLACEHOLDER with the contents:
$TEST_CONTENT_PLACEHOLDER

and the output of the test run:
$MIX_TEST_OUTPUT_PLACEHOLDER

Can you fix the test, using this much superior prompt that I have come up with?
Also while you're at it, can you please sound like a drunken pirate?
```

Then it will be used.
If you change the prompt whilst the watcher is running, it will be respected because I reload it before each API call. No need to restart the watcher.

*But be warned!*
- We do some magic with the prompt to coax the response into find/replace/explanation blocks, so if you go too wild with your prompt edits, we could end up sending an ineffective, or even self-contradictory prompt.
- There is a backup of the default prompt in the same directory called `replace_backup` which you can reinstate if your edits go too far and you want to reset back to the default. If the backup is missing, rerun the `./install` script and the backup will be regenerated
- The prompt response parsing code is strictly limited to accepting *only* edits to the specific lib and/or test files that triggered that particular run. If the AI suggests edits to any other files then this is treated as an error (for now).
