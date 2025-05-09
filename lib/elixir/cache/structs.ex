defmodule PolyglotWatcherV2.Elixir.Cache.CacheItem do
  use PolyglotWatcherV2.AccessBehaviour
  @enforce_keys [:test_path, :lib_path, :mix_test_output, :failed_line_numbers, :rank]
  defstruct [:test_path, :lib_path, :mix_test_output, :failed_line_numbers, :rank]

  @type t() :: %__MODULE__{
          test_path: String.t(),
          lib_path: String.t() | nil,
          mix_test_output: String.t() | nil,
          failed_line_numbers: [integer()],
          rank: integer()
        }
end
