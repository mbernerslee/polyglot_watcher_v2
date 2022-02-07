defmodule PolyglotWatcherV2.StartupMessage do
  alias PolyglotWatcherV2.Action

  def put_default_if_empty({:none, server_state}) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_startup_msg
         },
         put_startup_msg: %Action{
           runnable: {:puts, :magenta, "Watching for file saves..."},
           next_action: :exit
         }
       }
     }, server_state}
  end

  def put_default_if_empty(other) do
    other
  end
end
