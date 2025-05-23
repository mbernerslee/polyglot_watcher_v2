defmodule PolyglotWatcherV2.Const do
  def config_dir_path, do: "~/.config/polyglot_watcher_v2"

  def config_file_name, do: "config.yml"
  def backup_config_file_name, do: "config.yml.backup"

  def prompt_file_name, do: "prompt"
  def backup_prompt_file_name, do: "prompt.backup"

  def config_file_path, do: "#{config_dir_path()}/#{config_file_name()}"
  def config_backup_file_path, do: "#{config_dir_path()}/#{backup_config_file_name()}"
  def prompt_file_path, do: "#{config_dir_path()}/#{prompt_file_name()}"
  def prompt_backup_file_path, do: "#{config_dir_path()}/#{backup_prompt_file_name()}"

  def claude_3_5_sonnet_20240620, do: "claude-3-5-sonnet-20240620"
  def anthropic_api_key_env_var_name, do: "ANTHROPIC_API_KEY"

  def default_config_contents do
    """
      AI:
        vendor: Anthropic
        model: claude-3-5-sonnet-20240620
    """
  end

  def default_prompt do
    """
    <buffer>
      <name>
        Elixir Code
      </name>
      <filePath>
        $LIB_PATH_PLACEHOLDER
      </filePath>
      <content>
        $LIB_CONTENT_PLACEHOLDER
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Test
      </name>
      <filePath>
        $TEST_PATH_PLACEHOLDER
      </filePath>
      <content>
        $TEST_CONTENT_PLACEHOLDER
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Mix Test Output
      </name>
      <content>
        $MIX_TEST_OUTPUT_PLACEHOLDER
      </content>
    </buffer>

    *****

    Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide a diff, which when applied to the file containing the Elixir Code, will fix the test?

    """
  end
end
