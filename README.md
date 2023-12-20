<!-- Keep this up to date with the output of help -->
# PolyglotWatcherV2

A software development tool that triggers test runs test when files are saved, using a number of different user-specified modes.
See the section 'Watcher usage and modes' below.

## Installation

if you're on Debian or Mac simply do:

- `git clone git@github.com:mbernerslee/polyglot_watcher_v2.git`
- `cd polyglot_watcher_v2`
- `./install`
- now you can run `polyglot_watcher_v2` from anywhere

otherwise you'll have to look at how the `install` works and figure out how to install it on your OS.

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
| Fixed Last | `ex fl` | Runs `mix test [the most recent failure in memory]` when any *.ex* or *.exs* files are saved. <br /> I do this by keeping track of which tests have failed as I go. <br /> This means that when the most recently failed test passes, I'll start only running the next one that failed, and so on. <br /> Initialising in this mode is senseless because on startup my memory of failing tests is empty... <br /> So maybe try starting out in a different mode (e.g. Run All Mode) then switching to this one <br /> |

### Rust

| Mode | Switch | Description |
| ---- | ------ | ----------- |
| Default | `rs d` | Will always run `cargo build` when any `.rs` file is saved |
| Test | `rs t` | Will always run `cargo test` when any `.rs` file is saved |


## Quick guide to the codebase

 The entrypoint for the codebase is polyglot_watcher_v2.ex, def main
 * It starts up a supervised GenServer process, as defined in the Server module
 Server:
 * uses a filesystem watcher to watch for any changes in the current directory, and also listens for
 user input
 * handle_info will handle any output from the filesystem watcher, and use that to determine next actions
 to run, and then run those actions
 * set_ignore_file_changes is used to set whether file changes are being responded to or not
 * listen_for_user_input listens for input from the user, determines actions based on that input, and then
 runs those actions
 The main other modules of interest are:
 * Determine - holds logic for determining what actions to take based on filesystem changes (mainly
 delegated to relevant modules for each language like ElixirLangDeterminer)
 * UserInput - same as determine, but for input received from the user
 * TraverseActionsTree - interprets a tree of actions and executes them
