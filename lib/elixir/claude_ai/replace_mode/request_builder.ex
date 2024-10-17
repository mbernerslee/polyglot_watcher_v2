defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.RequestBuilder do
  alias PolyglotWatcherV2.ClaudeAI

  def build(
        %{files: %{lib: lib, test: test}, elixir: %{mix_test_output: mix_test_output}} =
          server_state
      )
      when not is_nil(mix_test_output) and not is_nil(lib) and not is_nil(test) do
    prompt = replace_placeholders(prompt(), lib, test, mix_test_output)

    messages = [%{role: "user", content: prompt}]

    ClaudeAI.build_api_request(server_state, messages)
  end

  def build(server_state) do
    {1, server_state}
  end

  defp replace_placeholders(prompt, lib, test, mix_test_output) do
    prompt
    |> String.replace("$LIB_PATH_PLACEHOLDER", lib.path)
    |> String.replace("$LIB_CONTENT_PLACEHOLDER", lib.contents)
    |> String.replace("$TEST_PATH_PLACEHOLDER", test.path)
    |> String.replace("$TEST_CONTENT_PLACEHOLDER", test.contents)
    |> String.replace("$MIX_TEST_OUTPUT_PLACEHOLDER", mix_test_output)
  end

  defp prompt do
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


    <Instruction>
      Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide *SEARCH/REPLACE/EXPLANATION* blocks for the Elixir Code file, which will fix the test?

      1. Decide if you need to propose *SEARCH/REPLACE/EXPLANATION* to the Elixir Code file

      2. Describe each change with a *SEARCH/REPLACE/EXPLANATION block* per the examples below.

      All changes to the Elixir Code file must use this *SEARCH/REPLACE/EXPLANATION block* format.
      ONLY EVER RETURN CODE IN A *SEARCH/REPLACE/EXPLANATION BLOCK*!

      Here are some example *SEARCH/REPLACE/EXPLANATION* block examples:

      <SEARCH>
      Enum.map([1, 2, 3], fn x -> x * 2 end)
      </SEARCH>
      <REPLACE>
      Enum.map([1, 2, 3], fn x -> x * x end)
      </REPLACE>
      <EXPLANATION>
      It looks we like were incorrectly multiplying the numbers by 2, rather than squaring them.
      </EXPLANATION>

      <SEARCH>
        words
      </SEARCH>
      <REPLACE>
        words
        |> Enum.map(fn word -> "cool " <> word end)
        |> MapSet.new()
      </REPLACE>
      <EXPLANATION>
      We need to prepend "cool " to each element in the list, and then convert the list into a MapSet.
      </EXPLANATION>

      <SEARCH>
      words
      |> MapSet.new()
      </SEARCH>
      <REPLACE>
      words
      |> Enum.map(fn word -> "ice cold " <> word end)
      |> MapSet.new()
      </REPLACE>
      <EXPLANATION>
      We need to prepend "ice cold " to each element in the list before converting the list into a MapSet.
      </EXPLANATION>


      ## Full Example Response:

      <SEARCH>
        list
        |> Enum.map(fn item -> "dude " <> item end)
      </SEARCH>
      <REPLACE>
        list
        |> Enum.map(fn item -> "dude " <> item end)
        |> MapSet.new()
      </REPLACE>
      <EXPLANATION>
      We need to convert the list into a MapSet.
      </EXPLANATION>

      <SEARCH>
        set
        |> MapSet.to_list()
        |> Enum.join("\n)
      </SEARCH>
      <REPLACE>
        set
        |> MapSet.to_list()
        |> Enum.join("\n")
      </REPLACE>
      <EXPLANATION>
      We are missing a closing double quote.
      </EXPLANATION>

      # *SEARCH/REPLACE/EXPLANATION block* Rules:

      Every *SEARCH/REPLACE/EXPLANATION block* must use this format:
      1. The start of search block: <SEARCH>
      2. A contiguous chunk of lines to search for in the existing source code
      3. The end of the search block: </SEARCH>
      4. The start of replace block: <REPLACE>
      5. The lines to replace into the source code
      6. The end of the replace block: </REPLACE>
      7. The start of explanation block: <EXPLANATION>
      8. A few lines explaining what the replacement code will do and how it fixes the test
      9. The end of the explanation block: </EXPLANATION>

      Every *SEARCH* section must *EXACTLY MATCH* the existing file content, character for character, including all comments, docstrings, etc.
      If the file contains code or other data wrapped/escaped in json/xml/quotes or other containers, you need to propose edits to the literal contents of the file, including the container markup.

      *SEARCH/REPLACE/EXPLANATION* blocks will replace *all* matching occurrences.
      Include enough lines to make the SEARCH blocks uniquely match the lines to change.

      *DO NOT* include three backticks: {%raw%}```{%endraw%} in your response!
      Keep *SEARCH/REPLACE/EXPLANATION* blocks concise.
      Break large *SEARCH/REPLACE/EXPLANATION* blocks into a series of smaller blocks that each change a small portion of the file.

      Empty <SEARCH> blocks mean that the replacement code must go at the top of the file.

    </Instruction>

    """
  end

  @doc """
  Untested hack
  Purely here for the sake of having an easier way to quickly iterate on the prompt within iex

  iex -S mix

  ```
  recompile(); PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode.RequestBuilder.hack()
  ```
  """
  def hack do
    messages = [%{role: "user", content: hack_prompt()}]

    %HTTPoison.Request{
      method: :post,
      url: "https://api.anthropic.com/v1/messages",
      headers: [
        {"x-api-key", System.fetch_env!("ANTHROPIC_API_KEY")},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ],
      body:
        Jason.encode!(%{
          max_tokens: 2048,
          model: "claude-3-5-sonnet-20240620",
          messages: messages
        }),
      options: [recv_timeout: 180_000]
    }
    |> HTTPoison.request!()
    |> Map.fetch!(:body)
    |> Jason.decode!()
    |> Map.fetch!("content")
    |> hd()
    |> Map.fetch!("text")
    |> IO.puts()
  end

  defp hack_prompt do
    lib_file =
      """
      """

    test_file =
      """
      defmodule FibTest do
        use ExUnit.Case
        doctest Fib

        # 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89,144,233,377,610,987, 1597, 2584, 4181

        test "can generate the given number of items of the Fibonacci sequence" do
          assert Fib.sequence(0) == []
          assert Fib.sequence(1) == [1]
          assert Fib.sequence(2) == [1, 1]
          assert Fib.sequence(3) == [1, 1, 2]
          assert Fib.sequence(4) == [1, 1, 2, 3]
          assert Fib.sequence(5) == [1, 1, 2, 3, 5]
          assert Fib.sequence(6) == [1, 1, 2, 3, 5, 8]
          assert Fib.sequence(7) == [1, 1, 2, 3, 5, 8, 13]

          assert Fib.sequence(19) == [
                   1,
                   1,
                   2,
                   3,
                   5,
                   8,
                   13,
                   21,
                   34,
                   55,
                   89,
                   144,
                   233,
                   377,
                   610,
                   987,
                   1597,
                   2584,
                   4181
                 ]
        end
      end
      """

    test_output =
      """
      Compiling 1 file (.ex)
      warning: Fib.sequence/1 is undefined or private
      Invalid call found at 9 locations:
        test/fib_test.exs:8: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:9: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:10: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:11: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:12: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:13: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:14: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:15: FibTest."test can generate the given number of items of the Fibonacci sequence"/1
        test/fib_test.exs:17: FibTest."test can generate the given number of items of the Fibonacci sequence"/1



        1) test can generate the given number of items of the Fibonacci sequence (FibTest)
           test/fib_test.exs:7
           ** (UndefinedFunctionError) function Fib.sequence/1 is undefined or private
           code: assert Fib.sequence(0) == []
           stacktrace:
             (fib 0.1.0) Fib.sequence(0)
             test/fib_test.exs:8: (test)


      Finished in 0.1 seconds (0.00s async, 0.1s sync)
      1 test, 1 failure

      Randomized with seed 295827
      """

    """
    <buffer>
      <name>
        Elixir Code
      </name>
      <filePath>
        lib/fib.ex
      </filePath>
      <content>
        #{lib_file}
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Test
      </name>
      <filePath>
        test/fib_test.exs
      </filePath>
      <content>
        #{test_file}
      </content>
    </buffer>

    <buffer>
      <name>
        Elixir Mix Test Output
      </name>
      <content>
        #{test_output}
      </content>
    </buffer>


    <Instruction>
      Given the above Elixir Code, Elixir Test, and Elixir Mix Test Output, can you please provide *SEARCH/REPLACE/EXPLANATION* blocks for the Elixir Code file, which will fix the test?

      1. Decide if you need to propose *SEARCH/REPLACE/EXPLANATION* to the Elixir Code file

      2. Describe each change with a *SEARCH/REPLACE/EXPLANATION block* per the examples below.

      All changes to the Elixir Code file must use this *SEARCH/REPLACE/EXPLANATION block* format.
      ONLY EVER RETURN CODE IN A *SEARCH/REPLACE/EXPLANATION BLOCK*!

      Here are some example *SEARCH/REPLACE/EXPLANATION* block examples:

      <SEARCH>
      Enum.map([1, 2, 3], fn x -> x * 2 end)
      </SEARCH>
      <REPLACE>
      Enum.map([1, 2, 3], fn x -> x * x end)
      </REPLACE>
      <EXPLANATION>
      It looks we like were incorrectly multiplying the numbers by 2, rather than squaring them.
      </EXPLANATION>

      <SEARCH>
        words
      </SEARCH>
      <REPLACE>
        words
        |> Enum.map(fn word -> "cool " <> word end)
        |> MapSet.new()
      </REPLACE>
      <EXPLANATION>
      We need to prepend "cool " to each element in the list, and then convert the list into a MapSet.
      </EXPLANATION>

      <SEARCH>
      words
      |> MapSet.new()
      </SEARCH>
      <REPLACE>
      words
      |> Enum.map(fn word -> "ice cold " <> word end)
      |> MapSet.new()
      </REPLACE>
      <EXPLANATION>
      We need to prepend "ice cold " to each element in the list before converting the list into a MapSet.
      </EXPLANATION>


      ## Full Example Response:

      <SEARCH>
        list
        |> Enum.map(fn item -> "dude " <> item end)
      </SEARCH>
      <REPLACE>
        list
        |> Enum.map(fn item -> "dude " <> item end)
        |> MapSet.new()
      </REPLACE>
      <EXPLANATION>
      We need to convert the list into a MapSet.
      </EXPLANATION>

      <SEARCH>
        set
        |> MapSet.to_list()
        |> Enum.join("\n)
      </SEARCH>
      <REPLACE>
        set
        |> MapSet.to_list()
        |> Enum.join("\n")
      </REPLACE>
      <EXPLANATION>
      We are missing a closing double quote.
      </EXPLANATION>

      # *SEARCH/REPLACE/EXPLANATION block* Rules:

      Every *SEARCH/REPLACE/EXPLANATION block* must use this format:
      1. The start of search block: <SEARCH>
      2. A contiguous chunk of lines to search for in the existing source code
      3. The end of the search block: </SEARCH>
      4. The start of replace block: <REPLACE>
      5. The lines to replace into the source code
      6. The end of the replace block: </REPLACE>
      7. The start of explanation block: <EXPLANATION>
      8. A few lines explaining what the replacement code will do and how it fixes the test
      9. The end of the explanation block: </EXPLANATION>

      Every *SEARCH* section must *EXACTLY MATCH* the existing file content, character for character, including all comments, docstrings, etc.
      If the file contains code or other data wrapped/escaped in json/xml/quotes or other containers, you need to propose edits to the literal contents of the file, including the container markup.

      *SEARCH/REPLACE/EXPLANATION* blocks will replace *all* matching occurrences.
      Include enough lines to make the SEARCH blocks uniquely match the lines to change.

      *DO NOT* include three backticks: {%raw%}```{%endraw%} in your response!
      Keep *SEARCH/REPLACE/EXPLANATION* blocks concise.
      Break large *SEARCH/REPLACE/EXPLANATION* blocks into a series of smaller blocks that each change a small portion of the file.

      Empty <SEARCH> blocks mean that the replacement code must go at the top of the file.

    </Instruction>

    """
  end
end
