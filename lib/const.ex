defmodule PolyglotWatcherV2.Const do
  def config_dir_path, do: "~/.config/polyglot_watcher_v2"
  def prompts_dir_path, do: config_dir_path() <> "/prompts"

  def config_file_name, do: "config.yml"
  def backup_config_file_name, do: "config_backup.yml"

  def replace_prompt_file_name, do: "replace"
  def backup_replace_prompt_file_name, do: "replace_backup"

  def config_file_path, do: "#{config_dir_path()}/#{config_file_name()}"
  def config_backup_file_path, do: "#{config_dir_path()}/#{backup_config_file_name()}"
  def replace_prompt_file_path, do: "#{prompts_dir_path()}/#{replace_prompt_file_name()}"

  def replace_prompt_backup_file_path,
    do: "#{prompts_dir_path()}/#{backup_replace_prompt_file_name()}"

  def claude_3_5_sonnet_20240620, do: "claude-3-5-sonnet-20240620"
  def anthropic_api_key_env_var_name, do: "ANTHROPIC_API_KEY"
  def gemini_api_key_env_var_name, do: "GEMINI_API_KEY"

  def default_config_contents do
    """
      AI:
        vendor: Anthropic
        model: claude-3-5-sonnet-20240620
    """
  end

  def default_replace_prompt do
    """
    Given the following -

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

    Can you please provide a list of updates to fix the issues?
    Don't add comments to the code please, leave commentary only in the explanation.
    """
  end
end
