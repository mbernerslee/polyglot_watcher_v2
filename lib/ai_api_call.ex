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

    {:ok, "cool api response"}
    # body =
    #   %{
    #     "messages" => [
    #       %{
    #         "role" => "system",
    #         "content" =>
    #           "You are a pirate assistant who understands the elixir programming language.
    #     You want to be helpful but you are also a deeply sarcastic person."
    #       },
    #       %{"role" => "user", "content" => question}
    #     ]
    #   }
    #   |> Jason.encode!()

    # options = [recv_timeout: 500_000]

    # case HTTPoison.post(@url, body, headers, options) do
    #   {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
    #     body
    #     |> Jason.decode!()
    #     |> decode_body()

    #   {:ok, %HTTPoison.Response{status_code: status_code} = error} ->
    #     {:error, "Received status code: #{status_code}. error = #{inspect(error)}"}

    #   {:error, %HTTPoison.Error{reason: reason}} ->
    #     {:error, reason}
    # end
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
    # test_failures = Failures.accumulate_failing_tests(test_output)

    # test_code =
    #   test_failures
    #   |> Enum.map(fn {test_file, _} -> test_file end)
    #   # |> IO.inspect(label: "XX")
    #   |> Enum.uniq()
    #   # |> IO.inspect(label: "test_code")
    #   |> Enum.reduce("", fn test_file, acc -> acc <> "\n" <> File.read!(test_file) end)

    # IO.puts("######## TEST CODE ###########################")

    # IO.puts(test_code)

    # test_failures_count = Enum.count(test_failures)

    test_files =
      test_output
      |> Failures.accumulate_failing_tests
      |> IO.inspect(label: "before")
      |> Enum.map(fn {test_file, _} -> test_file end)
      |> Enum.uniq()
      |> IO.inspect(label: "after")

      lib_files =
        test_files |> Enum.flat_map(fn test_file -> case test_to_lib(test_file) do
          {:ok, lib_file} ->
            [lib_file]
            _ -> []
        end
      end)
      |> IO.inspect()
      # |> Enum.flat_map(fn {_test, %{files: files}} -> files end)
      # |> Enum.uniq()
      # # |> IO.inspect(label: "staketrace_files")
      # |> Enum.reduce("", fn file, acc ->
      #   case File.read(file) do
      #     {:ok, contents} -> acc <> "\n" <> contents
      #     _ -> acc
      #   end
      # end)

    # IO.puts("######## STACKTRACE FILES ###########################")

    # IO.puts(test_code)

    # String.length(stacktrace_files) |> IO.inspect(label: "stacktrace_files length")
    # String.length(test_code) |> IO.inspect(label: "test_code length")
    # String.length(test_output) |> IO.inspect(label: "test_output length")

    #
    "hello"
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
