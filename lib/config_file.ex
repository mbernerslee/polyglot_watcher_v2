defmodule PolyglotWatcherV2.ConfigFile do
  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.Config
  alias PolyglotWatcherV2.Config.AI
  alias PolyglotWatcherV2.FileSystem

  @path Const.config_file_path()
  @default_config_contents Const.default_config_contents()
  @ai_vendors %{
    "Anthropic" => %{
      adapter: InstructorLite.Adapters.Anthropic,
      api_key_env_var_name: Const.anthropic_api_key_env_var_name()
    }
  }

  def read do
    with {:ok, contents} <- read_file(),
         {:ok, decoded} <- parse_yaml(contents),
         {:ok, config} <- build(decoded) do
      {:ok, config}
    end
  end

  defp read_file do
    path = Path.expand(@path)

    case FileSystem.read(path) do
      {:ok, contents} ->
        {:ok, contents}

      {:error, :enoent} ->
        {:error,
         """
         Error reading config file at #{path}, because it does not exist.
         You should have a backup at #{path}.backup, but failing that you can use the default of:

         ```
         #{@default_config_contents}
         ```
         """}

      {:error, error} ->
        {:error, "Error reading config file at #{path}. The error was #{inspect(error)}"}
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

      %{adapter: adapter, api_key_env_var_name: api_key_env_var_name} ->
        {:ok,
         %Config{
           ai: %AI{
             adapter: adapter,
             model: ai["model"],
             api_key_env_var_name: api_key_env_var_name
           }
         }}
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
