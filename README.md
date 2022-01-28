<!-- Keep this up to date with the output of help -->
# PolyglotWatcherV2

A software development tool that triggers test runs test when files are saved, using a number of different user-specified modes.
See the section 'Watcher usage and modes' below.

## Watcher usage and modes

I can...

- switch which watcher mode I'm using the fly while I'm running
- initialise in the desired mode by passing in command line arguments

using the switches listed below...


### Elixir

| Mode | Switcher | Description |
| ---- | -------- | ----------- |
| Default | `polyglot_watcher_v2 ex d` | Will run the equivalently pathed test only \

In other words: \
`mix test/x_test.exs` \

when these files are saved: \

- *lib/x.ex*
- *test/x_test.exs* |

<!--
#### Default Mode
`polyglot_watcher_v2 ex d`

Will run the equivalently pathed test only

In other words:
`mix test/x_test.exs`

when these files are saved:

- *lib/x.ex*
- *test/x_test.exs*


#### Run All Mode
`polyglot_watcher_v2 ex ra`

Runs `mix test` whenever any .ex or .exs file is saved


#### Fixed Mode
`polyglot_watcher_v2 ex f [path]`

Runs:
`mix test [path]` whenever any *.ex* or *.exs* file is saved
You can specify an exact line number e.g. `polyglot_watcher_v2 ex f test/cool_test.exs:100`, if you want.
OR without specifying `[path]`, runs `mix test [the most recent failure in memory]`
Initialising without specifying a path obviously doesn't really work because I'll have no memory of any test failures yet.

#### Fix All Mode
`polyglot_watcher_v2 ex fa`

Runs:
1. `mix test`
2. `mix test [single test only]` for each failing test in turn, until they're all fixed. Then we run 1. again to check we really are done


#### Fix All For File Mode
`polyglot_watcher_v2 ex faff [path]`

Runs:
1. `mix test [path]`
2. `mix test [path]:line_number_of_a_single_failure` for each failing line number in turn until it's fixed and then 1. again to check we really are done

#### Fixed Last Mode
`polyglot_watcher_v2 ex fl`

Only runs the most recently failed test when any *.ex* or *.exs* files are saved.
I do this by keeping track of which tests have failed as I go.
This means that when the most recently failed test passes, I'll start only running the next one that failed, and so on.
Initialising in this mode is senseless because on startup my memory of failing tests is empty...
So maybe try starting out in a different mode (e.g. Run All Mode) then switching to this one
-->


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
