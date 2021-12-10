# PolyglotWatcherV2

A software development tool that runs tests triggered when files are saved, usinga number of different user-specified modes
See the section 'Watcher usage and modes' below.

## Quick guide to the codebase

* The entrypoint for the codebase is polyglot_watcher_v2.ex, def main
  * It starts up a supervised GenServer process, as defined in the Server module
* Server:
  * uses a filesystem watcher to watch for any changes in the current directory, and also listens for
  user input
  * handle_info will handle any output from the filesystem watcher, and use that to determine next actions
  to run, and then run those actions
  * set_ignore_file_changes is used to set whether file changes are being responded to or not
  * listen_for_user_input listens for input from the user, determines actions based on that input, and then
  runs those actions
* The main other modules of interest are:
  * Determine - holds logic for determining what actions to take based on filesystem changes (mainly
  delegated to relevant modules for each language like ElixirLangDeterminer)
  * UserInput - same as determine, but for input received from the user
  * TraverseActionsTree - interprets a tree of actions and executes them

## Watcher usage and modes

This section of the readme is the output of running 'help' on the application itself

*General usage
  *  Switch between watcher modes per langage using the commands listed below.
  *  This can be done by on the fly by typing them in as I run...
  *  Equally you can pass them in on the command line arguments on startup, to initialise in the desired mode

*General Commands
*help
  *  see this message
*help_and_quit
  *  see this message and quit

*Elixir
*ex d
  *  Default Mode
  *  Will run the equivalently pathed test only
  *  In other words... mix test/x_test.exs when lib/x.ex or test/x_test.exs itself is saved
*ex ra
  *  Run All Mode
  *  Runs 'mix test' whenever any .ex or .exs file is saved
*ex f [path]
  *  Fixed Mode
  *  Runs 'mix test [path]' whenever any .ex or .exs file is saved
  *  You can specify an exact line number e.g. test/cool_test.exs:100, if you want
*ex fl
  *  Fixed Last Mode
  *  Only runs the most recently failed test when any .ex or .exs files are saved
  *  I do this by keeping track of which tests have failed as I go
  *  This means that when the most recently failed test passes, I'll start only running the next one that failed, and so on.
  *  Initialising in this mode isn't reccommended because on startup my memory of failing tests is empty...
  *  So maybe try starting out in a different mode (e.g. Run All Mode) then switching to this one
