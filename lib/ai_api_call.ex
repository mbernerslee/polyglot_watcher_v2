defmodule PolyglotWatcherV2.AIAPICall do
  alias PolyglotWatcherV2.Elixir.Failures
  alias PolyglotWatcherV2.Stacktrace

  @url "https://eastus2.api.cognitive.microsoft.com/openai/deployments/gpt4-0613/chat/completions?api-version=2023-05-15"

  def post(test_output) do
    headers = [
      {"Content-Type", "application/json"},
      {"api-key", System.get_env("AZURE_OPENAI_API_KEY")}
    ]

    question = build_question(test_output)

    body =
      %{
        "messages" => [
          %{
            "role" => "system",
            "content" =>
        #       "You are a pirate assistant who understands the elixir programming language.
        #  You want to be helpful but you are also a deeply sarcastic person."
        #   },
        #   %{"role" => "user", "content" => question}

              "You are a bot who understands the elixir programming language.
               You are an implementation within a test watcher that is being used to debug failing tests.
               You only show solutions as code snippets before explaining the issues
               Your responses are returned in a terminal"
          },
          %{
            "role" => "user",
            "content" => question
          }
        ]
      }
      |> Jason.encode!()

    options = [recv_timeout: 500_000]

    case HTTPoison.post(@url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> decode_body()

      {:ok, %HTTPoison.Response{status_code: status_code} = error} ->
        {:error, "Received status code: #{status_code}. error = #{inspect(error)}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp test_to_lib(test_file) do
    case Regex.named_captures(~r/test\/(?<file_body>[^\.]+)_test\.exs/, test_file) do
      %{"file_body" => file_body} ->
        {:ok, "lib/" <> file_body <> ".ex"}

      _ ->
        :error
    end
  end

  defp build_question(test_output) do
    test_files =
      test_output
      |> Failures.accumulate_failing_tests()
      |> Enum.map(fn {test_file, _} -> test_file end)
      |> Enum.uniq()

    lib_files =
      test_files
      |> Enum.flat_map(fn test_file ->
        case test_to_lib(test_file) do
          {:ok, lib_file} -> [lib_file]
          _ -> []
        end
      end)
      |> Enum.uniq()

    test_code =
      Enum.reduce(test_files, "", fn test_file, acc ->
        case File.read(test_file) do
          {:ok, contents} -> acc <> "\n" <> contents
          _ -> acc
        end
      end)

    lib_code =
      Enum.reduce(lib_files, "", fn lib_file, acc ->
        case File.read(lib_file) do
          {:ok, contents} -> acc <> "\n" <> contents
          _ -> acc
        end
      end)

    # IO.puts("######## TEST CODE ###########################")

    # IO.puts(test_code)

    # IO.puts("######## LIB CODE ###########################")

    # IO.puts(lib_code)

    faulty_test_response_example =
      ~s|
      ----------------------------------------------------------------
      \033[32m First test (test/elixir/fix_all_for_file_mode_test.exs:12): \033[0m

      ```
      test "fails given no provided test file or test failures in memory" do
        \033[31m raise "thing" <---- Here be the culprit \033[0m
        ...
      end
      ```

      Problem: The code raises an error on purpose.
      solution: Delete or comment out the raise function if it's not needed for the test.

      ----------------------------------------------------------------
      |


    """
    Do not introduce anything before providing the code snippets as solutions (eg. `Sure, here are the lines and explanations for the test errors:`)
    Talk as minimally as possible.
    Below is the output from running elixir tests with 'mix test'

    #{test_output}

    And also these are the tests files that failed:

    #{test_code}

    I'd like a marked up version of just the  test (not the whole file), highlighting the line where the error occurs,
    and an explanation about what is going wrong.

    In the case of the fault being in the test file, here is an example of what I want you to return: #{faulty_test_response_example}.
    You must include, an index for the test, the code snippet, problem, and solution.
    Do not specify the programming language before showing code snippets (eg. ```elixir.)
    Under no circumstances are you to use a different format for your response
    I also want you to put "<---- Here be the culprit" in red font for a terminal at the lines which are causing the failures.
    If you find multiple lines with faults, add this same thing to each line.
    If the fault is very simple, I want you to be very very brief. If the fault is not, I want you to explain as normal.


    And the underlying code of

    #{lib_code}

    Can you please provide me the correct code that woud make the tests pass?

    """
  end

  defp decode_body(body) do
    case body do
      %{
        "choices" => [%{"message" => %{"content" => content}} | _]
      } ->
        {:ok, content}

      other ->
        {:error, "Couldn't parse the body: #{inspect(other)}"}
    end
  end
end
