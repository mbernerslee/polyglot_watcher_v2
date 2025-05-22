defmodule PolyglotWatcherV2.ConfigFile do
  alias PolyglotWatcherV2.FileSystem
  alias PolyglotWatcherV2.Config
  alias PolyglotWatcherV2.Config.AI

  @path "~/.config/polyglot_watcher_v2/config.yml"
  @ai_vendors %{
    "Anthropic" => %{
      adapter: InstructorLite.Adapters.Anthropic
    }
  }

  # TODO wire this into server startup. Put an error & shut down the system if an error is returned. if OK put it into the server state.
  # TODO rename all the docs & code - removing references to Claude... say AI instead
  # TODO make claude modes use the model from the server state config
  # TODO update install script to put a default config in place when you install
  # TODO update README
  def read do
    with {:ok, contents} <- read_file(),
         {:ok, decoded} <- parse_yaml(contents),
         {:ok, config} <- build(decoded) do
      {:ok, config}
    end
  end

  defp read_file do
    case FileSystem.read(@path) do
      {:ok, contents} ->
        {:ok, contents}

      {:error, :enoent} ->
        {:error, "Error reading config file at #{@path}, because it does not exist"}

      {:error, error} ->
        {:error, "Error reading config file at #{@path}. The error was #{inspect(error)}"}
    end
  end

  defp parse_yaml(contents) do
    case YamlElixir.read_all_from_string(contents) do
      {:ok, decoded_yaml} ->
        {:ok, decoded_yaml}

      {:error, error} ->
        {:error,
         "Error decoding config file at ~/.config/polyglot_watcher_v2/config.yml. It is not valid YAML - #{inspect(error)}"}
    end
  end

  defp build([%{"AI" => %{"vendor" => vendor} = ai}]) do
    case Map.get(@ai_vendors, vendor) do
      nil ->
        {:error,
         "Error decoding config file at ~/.config/polyglot_watcher_v2/config.yml. Invalid vendor given. Vendors I accept are #{inspect(Map.keys(@ai_vendors))}"}

      %{adapter: adapter} ->
        {:ok, %Config{ai: %AI{adapter: adapter, model: ai["model"]}}}
    end
  end

  defp build(_) do
    {:error,
     """
     Error decoding config file at ~/.config/polyglot_watcher_v2/config.yml.
     There were some unexpected and/or missing fields.

     *********************
     example configs
     *********************
     AI:
       vendor: Anthropic
       model: claude-3-5-sonnet-20240620

     *********************
     or without specifying the model (to use the default model for the vendor):
     *********************

     AI:
       vendor: Anthropic
     *********************

     """}
  end
end
