defmodule Mix.Tasks.PolyglotWatcherV2.SetupConfigFilesTest do
  use ExUnit.Case, async: true
  use Mimic
  alias PolyglotWatcherV2.Const
  alias PolyglotWatcherV2.Puts
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias Mix.Tasks.PolyglotWatcherV2.SetupConfigFiles

  @default_config_contents Const.default_config_contents()
  @default_replace_prompt Const.default_replace_prompt()

  describe "run/1" do
    test "puts the expected files" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2/prompts" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :exists?, 2, fn _ ->
        false
      end)

      Mimic.expect(FileWrapper, :write, 4, fn
        "~/.config/polyglot_watcher_v2/config.yml", @default_config_contents -> :ok
        "~/.config/polyglot_watcher_v2/config_backup.yml", @default_config_contents -> :ok
        "~/.config/polyglot_watcher_v2/prompts/replace", @default_replace_prompt -> :ok
        "~/.config/polyglot_watcher_v2/prompts/replace_backup", @default_replace_prompt -> :ok
      end)

      Mimic.expect(Puts, :on_new_line, 4, fn
        _msg, :green -> :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == :normal
    end

    test "if creating the config dir fails, return an error" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        {:error, :some_error}
      end)

      Mimic.expect(Puts, :on_new_line, 1, fn msg, :red ->
        assert msg ==
                 "Failed to create directory ~/.config/polyglot_watcher_v2. The error was :some_error"

        :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == 1
    end

    test "if writing to the config file fails, return an error" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :exists?, 1, fn _ ->
        false
      end)

      Mimic.expect(FileWrapper, :write, 1, fn
        "~/.config/polyglot_watcher_v2/config.yml", @default_config_contents ->
          {:error, :some_error}

        "~/.config/polyglot_watcher_v2/config_backup.yml", @default_config_contents ->
          :ok

        "~/.config/polyglot_watcher_v2/prompts/replace", @default_replace_prompt ->
          :ok

        "~/.config/polyglot_watcher_v2/prompts/replace_backup", @default_replace_prompt ->
          :ok
      end)

      Mimic.expect(Puts, :on_new_line, 1, fn msg, :red ->
        assert msg ==
                 "Failed to write PolyglotWatcherV2 config file to ~/.config/polyglot_watcher_v2/config.yml. The error was :some_error"

        :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == 1
    end

    test "if writing to the config backup file fails, return an error" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :exists?, 1, fn _ ->
        false
      end)

      Mimic.expect(FileWrapper, :write, 2, fn
        "~/.config/polyglot_watcher_v2/config.yml", @default_config_contents ->
          :ok

        "~/.config/polyglot_watcher_v2/config_backup.yml", @default_config_contents ->
          {:error, :some_error}

        "~/.config/polyglot_watcher_v2/prompts/replace", @default_replace_prompt ->
          :ok

        "~/.config/polyglot_watcher_v2/prompts/replace_backup", @default_replace_prompt ->
          :ok
      end)

      Mimic.expect(Puts, :on_new_line, 2, fn
        _msg, :green ->
          :ok

        msg, :red ->
          assert msg ==
                   "Failed to write PolyglotWatcherV2 backup config file to ~/.config/polyglot_watcher_v2/config_backup.yml. The error was :some_error"

          :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == 1
    end

    test "if writing to the prompt file fails, return an error" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :exists?, 2, fn _ ->
        false
      end)

      Mimic.expect(FileWrapper, :write, 3, fn
        "~/.config/polyglot_watcher_v2/config.yml", @default_config_contents ->
          :ok

        "~/.config/polyglot_watcher_v2/config_backup.yml", @default_config_contents ->
          :ok

        "~/.config/polyglot_watcher_v2/prompts/replace", @default_replace_prompt ->
          {:error, :some_error}

        "~/.config/polyglot_watcher_v2/prompts/replace_backup", @default_replace_prompt ->
          :ok
      end)

      Mimic.expect(Puts, :on_new_line, 3, fn
        _msg, :green ->
          :ok

        msg, :red ->
          assert msg ==
                   "Failed to write PolyglotWatcherV2 prompt file to ~/.config/polyglot_watcher_v2/prompts/replace. The error was :some_error"

          :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == 1
    end

    test "if writing to the prompt backup file fails, return an error" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :exists?, 2, fn _ ->
        false
      end)

      Mimic.expect(FileWrapper, :write, 4, fn
        "~/.config/polyglot_watcher_v2/config.yml", @default_config_contents ->
          :ok

        "~/.config/polyglot_watcher_v2/config_backup.yml", @default_config_contents ->
          :ok

        "~/.config/polyglot_watcher_v2/prompts/replace", @default_replace_prompt ->
          :ok

        "~/.config/polyglot_watcher_v2/prompts/replace_backup", @default_replace_prompt ->
          {:error, :some_error}
      end)

      Mimic.expect(Puts, :on_new_line, 4, fn
        _msg, :green ->
          :ok

        msg, :red ->
          assert msg ==
                   "Failed to write PolyglotWatcherV2 backup prompt file to ~/.config/polyglot_watcher_v2/prompts/replace_backup. The error was :some_error"

          :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == 1
    end

    test "if the config file already exists, don't overwrite it" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :exists?, fn "~/.config/polyglot_watcher_v2/config.yml" ->
        true
      end)

      Mimic.expect(FileWrapper, :exists?, fn "~/.config/polyglot_watcher_v2/prompts/replace" ->
        false
      end)

      Mimic.expect(FileWrapper, :write, 3, fn
        "~/.config/polyglot_watcher_v2/config_backup.yml", @default_config_contents -> :ok
        "~/.config/polyglot_watcher_v2/prompts/replace", @default_replace_prompt -> :ok
        "~/.config/polyglot_watcher_v2/prompts/replace_backup", @default_replace_prompt -> :ok
      end)

      Mimic.expect(Puts, :on_new_line, 4, fn
        _msg, :green -> :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == :normal
    end

    test "if the prompt file already exists, don't overwrite it" do
      Mimic.expect(FileWrapper, :mkdir_p, fn "~/.config/polyglot_watcher_v2" ->
        :ok
      end)

      Mimic.expect(FileWrapper, :exists?, fn "~/.config/polyglot_watcher_v2/config.yml" ->
        false
      end)

      Mimic.expect(FileWrapper, :exists?, fn "~/.config/polyglot_watcher_v2/prompts/replace" ->
        true
      end)

      Mimic.expect(FileWrapper, :write, 3, fn
        "~/.config/polyglot_watcher_v2/config.yml", @default_config_contents -> :ok
        "~/.config/polyglot_watcher_v2/config_backup.yml", @default_config_contents -> :ok
        "~/.config/polyglot_watcher_v2/prompts/replace_backup", @default_replace_prompt -> :ok
      end)

      Mimic.expect(Puts, :on_new_line, 4, fn
        _msg, :green -> :ok
      end)

      assert catch_exit(SetupConfigFiles.run()) == :normal
    end
  end
end
