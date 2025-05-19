defmodule PolyglotWatcherV2.Action do
  @enforce_keys [:runnable, :next_action]
  defstruct runnable: nil, next_action: nil

  @type t() :: %__MODULE__{
          runnable:
            atom()
            | {atom(), any()}
            | {atom(), any(), any()}
            | {atom(), any(), any(), any()},
          next_action: atom() | %{fallack: any()}
        }
end

defmodule PolyglotWatcherV2.ActionTree do
  alias PolyglotWatcherV2.Action
  @type t() :: %{required(atom()) => Action.t()} | :none
end

defmodule PolyglotWatcherV2.Tree do
  alias PolyglotWatcherV2.ActionTree
  @enforce_keys [:entry_point, :action_tree]
  defstruct entry_point: nil, action_tree: nil

  @type t() :: %__MODULE__{
          entry_point: atom(),
          action_tree: ActionTree.t()
        }
end

defmodule PolyglotWatcherV2.ServerState do
  use PolyglotWatcherV2.AccessBehaviour
  @type file_info :: %{contents: String.t(), path: String.t()} | nil

  @type language_mode :: :default | any()
  @type os_type :: :mac | :linux

  @type elixir_state :: %{
          mode: language_mode(),
          claude_prompt: String.t() | nil
        }

  @type claude_ai_state :: %{
          response: any() | nil,
          request: any() | nil,
          phase: atom() | nil,
          file_updates: list() | nil
        }

  @type rust_state :: %{mode: language_mode()}

  @type t :: %__MODULE__{
          port: port() | nil,
          ignore_file_changes: boolean(),
          starting_dir: String.t() | nil,
          os: os_type() | nil,
          watcher: module() | nil,
          elixir: elixir_state(),
          claude_ai: claude_ai_state(),
          rust: rust_state(),
          env_vars: %{optional(String.t()) => String.t()},
          files: %{optional(any()) => file_info()},
          stored_actions: any(),
          action_error: any()
        }

  @enforce_keys [
    :port,
    :ignore_file_changes,
    :starting_dir,
    :os,
    :watcher,
    :elixir,
    :claude_ai,
    :rust,
    :env_vars,
    :files,
    :stored_actions,
    :action_error
  ]

  defstruct port: nil,
            ignore_file_changes: false,
            starting_dir: nil,
            os: nil,
            watcher: nil,
            elixir: %{mode: :default},
            claude_ai: %{},
            rust: %{mode: :default},
            env_vars: %{},
            files: %{},
            stored_actions: nil,
            action_error: nil
end
