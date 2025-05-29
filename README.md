<!-- Keep this up to date with the output of help -->
# PolyglotWatcherV2

A software development tool that triggers test runs test when files are saved, using a number of different user-specified modes.
See the section 'Watcher usage and modes' below.

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
