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

defmodule PolyglotWatcherV2.Patch do
  alias PolyglotWatcherV2.ActionTree
  @enforce_keys [:search, :replace, :index]
  defstruct search: nil, replace: nil, index: nil, explanation: nil

  @type t() :: %__MODULE__{
          search: String.t(),
          replace: String.t(),
          index: integer(),
          explanation: String.t() | nil
        }
end

defmodule PolyglotWatcherV2.FilePatch do
  alias PolyglotWatcherV2.Patch
  @enforce_keys [:contents, :patches]
  defstruct contents: nil, patches: []

  @type t() :: %__MODULE__{
          contents: String.t(),
          patches: [Patch.t()]
        }
end

defmodule PolyglotWatcherV2.ServerState do
  use PolyglotWatcherV2.AccessBehaviour
  alias PolyglotWatcherV2.FilePatch
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
          phase: atom() | nil
        }

  @type rust_state :: %{mode: language_mode()}

  @type file_patch :: {String.t(), FilePatch.t()}

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
          action_error: any(),
          file_patches: [file_patch()] | nil
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
    :action_error,
    :file_patches
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
            action_error: nil,
            file_patches: nil
end

defmodule PolyglotWatcherV2.Config do
  use PolyglotWatcherV2.AccessBehaviour

  defmodule AI do
    use PolyglotWatcherV2.AccessBehaviour
    @enforce_keys [:adapter, :model]
    defstruct adapter: nil, model: nil

    @type t :: %__MODULE__{
            adapter: module(),
            model: String.t() | nil
          }
  end

  @enforce_keys [:ai]
  defstruct ai: nil

  @type t() :: %__MODULE__{ai: AI.t()}
end
