# PolyglotWatcherV2

A software development tool that runs tests triggered when files are saved.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `polyglot_watcher_v2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:polyglot_watcher_v2, "~> 0.1.0"}
  ]
end
```

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

## Documentation
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/polyglot_watcher_v2](https://hexdocs.pm/polyglot_watcher_v2).

