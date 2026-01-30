defmodule PolyglotWatcherV2.Rust.Determiner do
  @behaviour PolyglotWatcherV2.Mode
  alias PolyglotWatcherV2.{Action, FilePath}

  @rs "rs"
  @extensions [@rs]

  def rs, do: @rs
  def extensions, do: @extensions

  @impl PolyglotWatcherV2.Mode
  def determine_actions(%FilePath{} = file_path, server_state) do
    if file_path.extension in @extensions do
      by_mode(file_path, server_state)
    else
      {:none, server_state}
    end
  end

  @impl PolyglotWatcherV2.Mode
  def user_input_actions(user_input, server_state) do
    rs_space = "#{@rs} "

    if String.starts_with?(user_input, rs_space) do
      user_input
      |> String.trim()
      |> String.trim_leading(rs_space)
      |> String.split(" ")
      |> map_user_input_to_actions(server_state)
    else
      {:none, server_state}
    end
  end

  # keep this up to date with README.md!
  def usage_puts do
    [
      {:magenta, "Rust\n"},
      {:light_magenta, "rs d\n"},
      {:white, "  Default Mode\n"},
      {:white, "  Will always run `cargo build` when any `.rs` file is saved\n"},
      {:light_magenta, "rs t\n"},
      {:white, "  Test Mode\n"},
      {:white, "  Will always run `cargo test` when any `.rs` file is saved\n"}
    ]
  end

  defp input_to_actions_mapping(user_input) do
    case user_input do
      ["d"] -> &switch_to_default_mode(&1)
      ["t"] -> &switch_to_test_mode(&1)
      _ -> nil
    end
  end

  defp map_user_input_to_actions(user_input, server_state) do
    case input_to_actions_mapping(user_input) do
      nil -> dont_undstand_user_input(server_state)
      actions_fun -> actions_fun.(server_state)
    end
  end

  defp dont_undstand_user_input(server_state) do
    {:none, server_state}
  end

  defp switch_to_default_mode(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switched Rust to default mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :rust, :default},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp switch_to_test_mode(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switched Rust to test mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :rust, :test},
           next_action: :exit
         }
       }
     }, server_state}
  end

  defp by_mode(_file_path, server_state) do
    case server_state.rust.mode do
      :default ->
        default_mode(server_state)

      :test ->
        test_mode(server_state)
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

  defp test_mode(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_intent_msg
         },
         put_intent_msg: %Action{
           runnable: {:puts, :magenta, "Running cargo test"},
           next_action: :cargo_test
         },
         cargo_test: %Action{
           runnable: :cargo_test,
           next_action: %{0 => :put_success_msg, :fallback => :put_failure_msg}
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end
end
