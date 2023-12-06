defmodule PolyglotWatcherV2.AIAPICall do
  alias PolyglotWatcherV2.Elixir.Failures

  @url "https://eastus2.api.cognitive.microsoft.com/openai/deployments/gpt4-0613/chat/completions?api-version=2023-05-15"

  def post(test_output) do
    headers = [
      {"Content-Type", "application/json"},
      {"api-key", System.get_env("AZURE_OPENAI_API_KEY")}
    ]

    test_code =
      test_output
      |> Failures.accumulate_failing_tests()
      |> Enum.reduce("", fn {test_file, _}, acc -> acc <> "\n" <> File.read!(test_file) end)

    body =
      %{
        "messages" => [
          %{
            "role" => "system",
            "content" =>
              "You are a pirate assistant who understands the elixir programming language.
          You want to be helpful but you are also a deeply sarcastic person."
          },
          %{
            "role" => "user",
            "content" => """
            Below is the output from running elixir tests with 'mix test'

              #{test_output}

            And also these are the tests files that failed:

            #{test_code}

            What does it look like is going wrong and how should I fix it?
            """
          }
        ]
      }
      |> Jason.encode!()

    options = [recv_timeout: 100_000]

    case HTTPoison.post(@url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> decode_body()

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
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
