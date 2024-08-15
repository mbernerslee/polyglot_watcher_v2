defmodule PolyglotWatcherV2.Elixir.ClaudeAI.CodeblockTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.ServerStateBuilder
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.Elixir.ClaudeAI.Codeblock

  describe "write_to_lib_file/1" do
    test "when an elixir codeblock is found, write it to the file, leaving the old code commented below" do
      lib_path = "lib/cool.ex"
      lib_contents = "cool lib"
      lib_file = %{path: lib_path, contents: lib_contents}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"
      prompt = "cool prompt dude"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_claude_prompt(prompt)
        |> ServerStateBuilder.with_claude_ai_response(
          {:ok, {:parsed, response_text_with_elixir_codeblock()}}
        )

      Mimic.expect(FileWrapper, :write, fn path, content ->
        assert path == lib_path

        assert content == """
               #{elixir_codeblock_contents()}
               ##########################
               ## previous code version
               ##########################
               ## #{lib_contents}
               ##########################
               """

        :ok
      end)

      assert {0, server_state} ==
               Codeblock.write_to_lib_file(server_state)
    end

    test "do not comment out already commented lines" do
      lib_path = "lib/cool.ex"

      lib_contents = """
      cool lib
      ##########################
      ## previous code version
      ##########################
      ## already commented out
      ## already commented out 2
      """

      lib_file = %{path: lib_path, contents: lib_contents}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"
      prompt = "cool prompt dude"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_claude_prompt(prompt)
        |> ServerStateBuilder.with_claude_ai_response(
          {:ok, {:parsed, response_text_with_elixir_codeblock()}}
        )

      Mimic.expect(FileWrapper, :write, fn path, content ->
        assert path == lib_path

        assert content == """
               #{elixir_codeblock_contents()}
               ##########################
               ## previous code version
               ##########################
               ## cool lib
               ##########################
               ## previous code version
               ##########################
               ## already commented out
               ## already commented out 2
               ##########################
               """

        :ok
      end)

      assert {0, server_state} ==
               Codeblock.write_to_lib_file(server_state)
    end

    test "when there's no codeblock, return error" do
      lib_path = "lib/cool.ex"
      lib_contents = "cool lib"
      lib_file = %{path: lib_path, contents: lib_contents}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"
      prompt = "cool prompt dude"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_claude_prompt(prompt)
        |> ServerStateBuilder.with_claude_ai_response({:ok, {:parsed, "nope"}})

      Mimic.reject(&FileWrapper.write/2)

      assert {1, server_state} ==
               Codeblock.write_to_lib_file(server_state)
    end

    test "when writing the file errors, return error" do
      lib_path = "lib/cool.ex"
      lib_contents = "cool lib"
      lib_file = %{path: lib_path, contents: lib_contents}
      test_file = %{path: "test/cool_test.exs", contents: "cool test"}
      mix_test_output = "it failed mate. get good."
      api_key = "super-secret"
      prompt = "cool prompt dude"

      server_state =
        ServerStateBuilder.build()
        |> ServerStateBuilder.with_file(:lib, lib_file)
        |> ServerStateBuilder.with_file(:test, test_file)
        |> ServerStateBuilder.with_mix_test_output(mix_test_output)
        |> ServerStateBuilder.with_env_var("ANTHROPIC_API_KEY", api_key)
        |> ServerStateBuilder.with_claude_prompt(prompt)
        |> ServerStateBuilder.with_claude_ai_response(
          {:ok, {:parsed, response_text_with_elixir_codeblock()}}
        )

      Mimic.expect(FileWrapper, :write, fn _path, _content ->
        {:error, :enoent}
      end)

      assert {1, server_state} ==
               Codeblock.write_to_lib_file(server_state)
    end
  end

  defp response_text_with_elixir_codeblock do
    """
    Sure, here's the diff:

    ```elixir
    #{elixir_codeblock_contents()}
    ```

    The diff is cool, right?
    """
  end

  defp elixir_codeblock_contents do
    """
    defmodule Cool do
      def cool do
        "cool"
      end
    end
    """
  end
end
