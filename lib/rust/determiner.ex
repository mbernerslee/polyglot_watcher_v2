defmodule PolyglotWatcherV2.Rust.Determiner do
  alias PolyglotWatcherV2.{Action, FilePath}

  @rs "rs"
  @extensions [@rs]

  def rs, do: @rs

  def determine_actions(%FilePath{} = file_path, server_state) do
    if file_path.extension in @extensions do
      by_mode(file_path, server_state)
    else
      {:none, server_state}
    end
  end

  defp by_mode(_file_path, server_state) do
    case server_state.rust.mode do
      :default ->
        default_mode(server_state)
    end
  end

  defp default_mode(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_intent_msg
         },
         put_intent_msg: %Action{
           runnable: {:puts, :magenta, "Running cargo build"},
           next_action: :cargo_build
         },
         cargo_build: %Action{
           runnable: :cargo_build,
           next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end
end
