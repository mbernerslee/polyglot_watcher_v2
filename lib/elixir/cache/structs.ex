defmodule PolyglotWatcherV2.Elixir.Cache.TestFile do
  use PolyglotWatcherV2.AccessBehaviour

  @enforce_keys [:path, :contents, :failed_line_numbers]
  defstruct [:path, :contents, :failed_line_numbers]

  @type t() :: %__MODULE__{
          path: String.t(),
          contents: String.t(),
          failed_line_numbers: [integer()]
        }
end

defmodule PolyglotWatcherV2.Elixir.Cache.LibFile do
  use PolyglotWatcherV2.AccessBehaviour

  @enforce_keys [:path, :contents]
  defstruct [:path, :contents]

  @type t() :: %__MODULE__{
          path: String.t() | nil,
          contents: String.t() | nil
        }
end

defmodule PolyglotWatcherV2.Elixir.Cache.File do
  use PolyglotWatcherV2.AccessBehaviour
  alias PolyglotWatcherV2.Elixir.Cache.{LibFile, TestFile}

  @enforce_keys [:test, :lib, :mix_test_output, :rank]
  defstruct [:test, :lib, :mix_test_output, :rank]

  @type t() :: %__MODULE__{
          test: TestFile.t(),
          lib: LibFile.t(),
          mix_test_output: String.t() | nil,
          rank: integer()
        }
end

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
