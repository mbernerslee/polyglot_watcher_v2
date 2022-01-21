defmodule PolyglotWatcherV2.Elm.Determiner do
  alias PolyglotWatcherV2.{Action, FilePath}
  @elm "elm"

  def elm, do: @elm

  def determine_actions(%FilePath{path: path, extension: @elm} = file_path, server_state) do
    stringified_file_path = FilePath.stringify(file_path)

    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :find_elm_json
         },
         find_elm_json: %Action{
           runnable: {:find_elm_json, file_path},
           next_action: %{0 => :put_finding_main_msg, :fallback => :no_elm_json}
         },
         no_elm_json: %Action{
           runnable:
             {:puts, :red,
              "I failed to find an elm.json file when you saved #{stringified_file_path}, so I'm giving up"},
           next_action: %{0 => :put_finding_main_msg, :fallback => :no_elm_json}
         },
         put_finding_main_msg: %Action{
           runnable: {:puts, :magenta, "Searching for Main.elm for #{stringified_file_path}"},
           next_action: :find_elm_main
         },
         find_elm_main: %Action{
           runnable: {:find_elm_main, file_path},
           next_action: %{0 => :elm_make, :fallback => :no_elm_main}
         },
         no_elm_main: %Action{
           runnable:
             {:puts, :red,
              "I couldn't find a corresponding Main.elm for #{stringified_file_path}, so I'm giving up :-("},
           next_action: :exit
         },
         elm_make: %Action{
           runnable: :elm_make,
           next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end

  def determine_actions(_, server_state) do
    {:none, server_state}
  end
end
