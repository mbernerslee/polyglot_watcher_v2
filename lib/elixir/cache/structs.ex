defmodule PolyglotWatcherV2.Elixir.Cache.TestFile do
  @enforce_keys [:path, :contents, :failed_line_numbers]
  defstruct [:path, :contents, :failed_line_numbers]

  @type t() :: %__MODULE__{
          path: String.t(),
          contents: String.t(),
          failed_line_numbers: [integer()]
        }
end

defmodule PolyglotWatcherV2.Elixir.Cache.LibFile do
  @enforce_keys [:path, :contents]
  defstruct [:path, :contents]

  @type t() :: %__MODULE__{
          path: String.t() | nil,
          contents: String.t() | nil
        }
end

defmodule PolyglotWatcherV2.Elixir.Cache.File do
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
