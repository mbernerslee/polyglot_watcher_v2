defmodule PolyglotWatcherV2.Mode do
  alias PolyglotWatcherV2.FilePath
  alias PolyglotWatcherV2.ActionTree
  alias PolyglotWatcherV2.ServerState

  @callback determine_actions(server_state :: ServerState.t()) ::
              {ActionTree.t(), ServerState.t()}
  @callback determine_actions(file_path :: FilePath.t(), server_state :: ServerState.t()) ::
              {ActionTree.t(), ServerState.t()}

  @callback switch(server_state :: ServerState.t()) :: {ActionTree.t(), ServerState.t()}
  @callback switch(server_state :: ServerState.t(), anything :: any()) ::
              {ActionTree.t(), ServerState.t()}

  @callback user_input_actions(user_input :: String.t(), server_state :: ServerState.t()) ::
              {ActionTree.t(), ServerState.t()} | {false, ServerState.t()}

  # They're all optional because at least 1 determine_actions & switch of any arity is required, which can't be expressed with @optional_callbacks.
  @optional_callbacks determine_actions: 1,
                      determine_actions: 2,
                      switch: 1,
                      switch: 2,
                      user_input_actions: 2
end
