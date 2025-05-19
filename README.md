<!-- Keep this up to date with the output of help -->
# PolyglotWatcherV2

A software development tool that triggers test runs test when files are saved, using a number of different user-specified modes.
See the section 'Watcher usage and modes' below.

## Installation

### Prerequisites
- [Elixir](https://elixir-lang.org/) >= 1.18 - Probably works with somewhat lower versions, but not for sure
- [Erlang / OTP 27](https://www.erlang.org/)
- It's highly recommended to install both with [ASDF](https://asdf-vm.com/guide/getting-started.html)

if you're on Debian or Mac simply do:

- `git clone git@github.com:mbernerslee/polyglot_watcher_v2.git`
- `cd polyglot_watcher_v2`
- `./install`
- now you can run `polyglot_watcher_v2` from anywhere

...otherwise you'll have to look at how the `install` script works and figure out how to install it on your OS.

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
| Claude | `ex cl` | The same as default mode, but if the test fails then an automatic API call is made to Anthropic's Claude AI asking it if it can fix the test <br /> It auto-generates the prompt with the lib file, test file & mix test output for you, and you can set your own custom prompt. <br /> Requires a valid ANTHROPIC_API_KEY environment variable to be on your system.<br /> See below for more details |
| Claude Replace | `ex clr` | The same as the above mode, but uses a hard-coded prompt resulting in find/replace suggestion codeblocks to fix the test |

### Rust

| Mode | Switch | Description |
| ---- | ------ | ----------- |
| Default | `rs d` | Will always run `cargo build` when any `.rs` file is saved |
| Test | `rs t` | Will always run `cargo test` when any `.rs` file is saved |

## Elixir Claude Mode

### Requirements

Have a valid `ANTHROPIC_API_KEY` environment variable on your system.
See [https://docs.anthropic.com/en/docs/welcome](https://docs.anthropic.com/en/docs/welcome)

### What it does

By default this mode will trigger the following on file save:

- determine the equivalent lib / test file depending on which was saved
- run `mix test <test_file>`
- if the test fails, it will make an API call to Anthropic's Claude AI to ask it if it can fix the test

The prompt is generated for you, and it splices the lib file, test file and the output of the test run into it.

### Custom prompt

You can override the default prompt by placing a file at
`~/.config/polyglot_watcher_v2/prompt`

The following placeholders will get be replaced with the real thing at runtime:
- `$LIB_PATH_PLACEHOLDER`
- `$LIB_CONTENT_PLACEHOLDER`
- `$TEST_PATH_PLACEHOLDER`
- `$TEST_CONTENT_PLACEHOLDER`
- `$MIX_TEST_OUTPUT_PLACEHOLDER`

Meaning that you can have a prompt like this at `~/.config/polyglot_watcher_v2/prompt`:

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

