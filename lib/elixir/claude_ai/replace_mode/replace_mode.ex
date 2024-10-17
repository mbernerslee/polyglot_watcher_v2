defmodule PolyglotWatcherV2.Elixir.ClaudeAI.ReplaceMode do
  alias PolyglotWatcherV2.{Action, FilePath}
  alias PolyglotWatcherV2.Elixir.{Determiner, EquivalentPath}

  @ex Determiner.ex()
  @exs Determiner.exs()

  def switch(server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_switch_mode_msg
         },
         put_switch_mode_msg: %Action{
           runnable: {:puts, :magenta, "Switching to Claude AI Replace mode"},
           next_action: :switch_mode
         },
         switch_mode: %Action{
           runnable: {:switch_mode, :elixir, :claude_ai_replace},
           next_action: :persist_api_key
         },
         persist_api_key: %Action{
           runnable: {:persist_env_var, "ANTHROPIC_API_KEY"},
           next_action: %{0 => :put_awaiting_file_save_msg, :fallback => :no_api_key_fail_msg}
         },
         no_api_key_fail_msg: %Action{
           runnable:
             {:puts, :red,
              "I read the environment variable 'ANTHROPIC_API_KEY', but nothing was there, so I'm giving up! Try setting it and running me again..."},
           next_action: :exit
         },
         put_awaiting_file_save_msg: %Action{
           runnable: {:puts, :magenta, "Awaiting a file save..."},
           next_action: :exit
         }
       }
     }, server_state}
  end

  def determine_actions(%FilePath{extension: @exs} = test_path, server_state) do
    test_path_string = FilePath.stringify(test_path)

    case EquivalentPath.determine(test_path) do
      {:ok, lib_path} ->
        determine_actions(lib_path, test_path_string, server_state)

      :error ->
        {cannot_determine_lib_path_from_test_path(test_path_string), server_state}
    end
  end

  def determine_actions(%FilePath{extension: @ex} = lib_path, server_state) do
    lib_path_string = FilePath.stringify(lib_path)

    case EquivalentPath.determine(lib_path) do
      {:ok, test_path} ->
        determine_actions(lib_path_string, test_path, server_state)

      :error ->
        {cannot_determine_test_path_from_lib_path(lib_path_string), server_state}
    end
  end

  defp determine_actions(lib_path, test_path, server_state) do
    {%{
       entry_point: :clear_screen,
       actions_tree: %{
         clear_screen: %Action{
           runnable: :clear_screen,
           next_action: :put_intent_msg
         },
         put_intent_msg: %Action{
           runnable: {:puts, :magenta, "Running mix test #{test_path}"},
           next_action: :mix_test
         },
         mix_test: %Action{
           runnable: {:mix_test, test_path},
           next_action: %{0 => :put_success_msg, :fallback => :put_claude_init_msg}
         },
         put_claude_init_msg: %Action{
           runnable: {:puts, :magenta, "Doing some Claude setup..."},
           next_action: :put_perist_files_msg
         },
         put_perist_files_msg: %Action{
           runnable: {:puts, :magenta, "Saving the lib & test files to memory..."},
           next_action: :persist_lib_file
         },
         persist_lib_file: %Action{
           runnable: {:persist_file, lib_path, :lib},
           next_action: %{0 => :persist_test_file, :fallback => :missing_file_msg}
         },
         persist_test_file: %Action{
           runnable: {:persist_file, test_path, :test},
           next_action: %{
             0 => :build_claude_replace_api_request,
             :fallback => :missing_file_msg
           }
         },
         # TODO get rid of this "placeholder error" in all files. more descriptive errors please
         build_claude_replace_api_request: %Action{
           runnable: :build_claude_replace_api_request,
           next_action: %{
             0 => :put_calling_claude_msg,
             :fallback => :fallback_placeholder_error
           }
         },
         put_calling_claude_msg: %Action{
           runnable: {:puts, :magenta, "Waiting for Claude API call response..."},
           next_action: :perform_claude_api_request
         },
         perform_claude_api_request: %Action{
           runnable: :perform_claude_api_request,
           next_action: %{
             0 => :parse_claude_api_response,
             :fallback => :fallback_placeholder_error
           }
         },
         parse_claude_api_response: %Action{
           runnable: :parse_claude_replace_api_response,
           next_action: %{
             0 => :exit,
             :fallback => :fallback_placeholder_error
           }
         },
         missing_file_msg: %Action{
           runnable:
             {:puts, :red,
              """
              You saved one of these, but the other doesn't exist:

                #{lib_path}
                #{test_path}

              So you're beyond this particular Claude integrations help until both exist.
              Create the missing one please!
              """},
           next_action: :put_failure_msg
         },
         fallback_placeholder_error: %Action{
           runnable:
             {:puts, :red,
              """
              Claude fallback error
              Oh no!
              """},
           next_action: :put_failure_msg
         },
         put_success_msg: %Action{runnable: :put_sarcastic_success, next_action: :exit},
         put_failure_msg: %Action{runnable: :put_insult, next_action: :exit}
       }
     }, server_state}
  end

  defp cannot_determine_test_path_from_lib_path(lib_path) do
    %{
      entry_point: :clear_screen,
      actions_tree: %{
        clear_screen: %Action{
          runnable: :clear_screen,
          next_action: :cannot_find_msg
        },
        cannot_find_msg: %Action{
          runnable:
            {:puts, :magenta,
             """
             You saved this file, but I can't work out what I should try and run:

               #{lib_path}

             Hmmmmm...

             """},
          next_action: :exit
        }
      }
    }
  end

  defp cannot_determine_lib_path_from_test_path(test_path) do
    %{
      entry_point: :clear_screen,
      actions_tree: %{
        clear_screen: %Action{
          runnable: :clear_screen,
          next_action: :cannot_find_msg
        },
        cannot_find_msg: %Action{
          runnable:
            {:puts, :magenta,
             """
             You saved this test file, but I can't figure out what it's equivalent lib file is

               #{test_path}

             Hmmmmm...

             """},
          next_action: :exit
        }
      }
    }
  end

  @doc """
  Untested hack
  Purely here for having an easier way to quickly iterate on the prompt within iex
  """
  def hack do
    prompt = """
      What's your favourite colour?
    """

    messages = [%{role: "user", content: prompt()}]

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

  defp prompt do
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
