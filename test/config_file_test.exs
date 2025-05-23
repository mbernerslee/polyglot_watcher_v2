defmodule PolyglotWatcherV2.ConfigFileTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.Config
  alias PolyglotWatcherV2.Config.AI
  alias PolyglotWatcherV2.ConfigFile
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @path "/home/berners/.config/polyglot_watcher_v2/config.yml"
  @config_with_model """
    AI:
      vendor: Anthropic
      model: claude-3-5-sonnet-20240620

  """
  @config_without_model """
    AI:
      vendor: Anthropic

  """
  @default_config_contents Const.default_config_contents()
  @anthropic_api_key_env_var_name Const.anthropic_api_key_env_var_name()

  test "default_config_contents returns a valid config" do
    Mimic.expect(FileWrapper, :read, 1, fn
      @path -> {:ok, @default_config_contents}
    end)

    assert {:ok,
            %Config{
              ai: %AI{
                adapter: InstructorLite.Adapters.Anthropic,
                model: "claude-3-5-sonnet-20240620",
                api_key_env_var_name: @anthropic_api_key_env_var_name
              }
            }} == ConfigFile.read()
  end

  describe "read/1" do
    test "when a valid file exists, it is read" do
      Mimic.expect(FileWrapper, :read, 1, fn
        @path -> {:ok, @config_with_model}
      end)

      assert {:ok,
              %Config{
                ai: %AI{
                  adapter: InstructorLite.Adapters.Anthropic,
                  model: "claude-3-5-sonnet-20240620",
                  api_key_env_var_name: @anthropic_api_key_env_var_name
                }
              }} == ConfigFile.read()
    end

    test "when no model is specified, thats ok and we put model = nil" do
      Mimic.expect(FileWrapper, :read, 1, fn
        @path -> {:ok, @config_without_model}
      end)

      assert {:ok,
              %Config{
                ai: %AI{
                  adapter: InstructorLite.Adapters.Anthropic,
                  model: nil,
                  api_key_env_var_name: @anthropic_api_key_env_var_name
                }
              }} == ConfigFile.read()
    end

    test "when the config file does not exist, return error" do
      Mimic.expect(FileWrapper, :read, 1, fn
        @path -> {:error, :enoent}
      end)

      assert {:error,
              """
              Error reading config file at #{@path}, because it does not exist.
              You should have a backup at #{@path}.backup, but failing that you can use the default of:

              ```
                AI:
                  vendor: Anthropic
                  model: claude-3-5-sonnet-20240620

              ```
              """} == ConfigFile.read()
    end

    test "when there's an error opening the config file, return error" do
      Mimic.expect(FileWrapper, :read, 1, fn
        @path -> {:error, :eacces}
      end)

      assert {:error, "Error reading config file at #{@path}. The error was :eacces"} ==
               ConfigFile.read()
    end

    test "when the config file returns something that is not YAML, return error" do
      invalid_yaml_contents = """
      AI:
        vendor: Anthropic
        model: claude-3-5-sonnet-20240620
      invalid_yaml: [unclosed bracket
      """

      Mimic.expect(FileWrapper, :read, 1, fn
        @path -> {:ok, invalid_yaml_contents}
      end)

      assert {:error,
              "Error decoding config file at ~/.config/polyglot_watcher_v2/config.yml. It is not valid YAML - %YamlElixir.ParsingError{line: 4, column: 32, type: :unfinished_flow_collection, message: \"Unfinished flow collection\"}"} =
               ConfigFile.read()
    end

    test "when the config file is valid YAML but does not contain the expected mandatory fields, return error" do
      missing_fields_contents = """
      SomeOtherField:
        value: test
      """

      Mimic.expect(FileWrapper, :read, 1, fn
        @path -> {:ok, missing_fields_contents}
      end)

      assert {:error,
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

              """} == ConfigFile.read()
    end

    test "given an invalid AI vendor, return error" do
      invalid_vendor_contents = """
      AI:
        vendor: InvalidVendor
        model: some-model
      """

      Mimic.expect(FileWrapper, :read, 1, fn
        @path -> {:ok, invalid_vendor_contents}
      end)

      assert {:error,
              "Error decoding config file at ~/.config/polyglot_watcher_v2/config.yml. Invalid vendor given. Vendors I accept are [\"Anthropic\"]"} ==
               ConfigFile.read()
    end
  end
end
