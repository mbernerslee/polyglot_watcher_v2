#!/usr/bin/env elixir

Mix.install([{:req, "~> 0.5.0"}, {:instructor_lite, "~> 0.3.0"}, {:instructor, "~> 0.1.0"}])

defmodule Lite.LLMExplainer do
  use Ecto.Schema
  use InstructorLite.Instruction

  @primary_key false
  embedded_schema do
    field :tldr, :string
    field :long_version, :string
  end
end

# config = [
#  adapter: Instructor.Adapters.Gemini,
#  api_key: System.fetch_env!("GEMINI_API_KEY")
# ]

config = [
  adapter: Instructor.Adapters.Anthropic,
  api_key: System.fetch_env!("ANTHROPIC_API_KEY")
]

defmodule President do
  use Ecto.Schema
  use Instructor

  @primary_key false
  @llm_doc """
    hi
  """
  embedded_schema do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:entered_office_date, :date)
  end
end

# Instructor.chat_completion(
#  [
#    model: "gemini-2.0-flash",
#    mode: :json_schema,
#    response_model: President,
#    messages: [
#      %{role: "user", content: "Who was the first president of the United States?"}
#    ]
#  ],
#  config
# )
# |> IO.inspect()

Instructor.chat_completion(
  [
    model: "claude-3-5-haiku-20241022",
    # mode: :tools,
    max_tokens: 1000,
    response_model: President,
    messages: [
      %{role: "user", content: "Who was the first president of the United States?"}
    ]
  ],
  config
)
|> IO.inspect()

# {adapter, model, api_key} =
#  case System.argv() do
#    ["a", model] ->
#      {InstructorLite.Adapters.Anthropic, model, System.fetch_env!("ANTHROPIC_API_KEY")}
#
#    ["g"] ->
#      {InstructorLite.Adapters.Gemini, "", System.fetch_env!("GEMINI_API_KEY")}
#
#    ["g", model] ->
#      {InstructorLite.Adapters.Gemini, model, System.fetch_env!("GEMINI_API_KEY")}
#
#    [] ->
#      {InstructorLite.Adapters.Anthropic, "claude-3-5-sonnet-20240620",
#       System.fetch_env!("ANTHROPIC_API_KEY")}
#
#    _ ->
#      raise "No worky"
#  end
#  |> IO.inspect()
#
# IO.inspect("Using adapter #{inspect(adapter)}")
# IO.inspect("Using model #{model}")
#
# json_schema =
#  InstructorLite.JSONSchema.from_ecto_schema(Lite.LLMExplainer)
#  |> Map.delete(:additionalProperties)
#  |> IO.inspect()
#
# %{
#  type: "object",
#  required: [:tldr, :long_version],
#  properties: %{tldr: %{type: "string"}, long_version: %{type: "string"}}
# }
# |> IO.inspect()
#
# case adapter do
#  InstructorLite.Adapters.Gemini ->
#    InstructorLite.instruct(
#      %{contents: [%{role: "user", parts: [%{text: "Can you explain LLMs to me?"}]}]},
#      response_model: Lite.LLMExplainer,
#      json_schema: json_schema,
#      adapter: InstructorLite.Adapters.Gemini,
#      adapter_context: [
#        model: "gemini-1.5-flash-8b",
#        api_key: api_key
#      ]
#    )
#
#  InstructorLite.Adapters.Anthropic ->
#    InstructorLite.instruct(
#      %{
#        messages: [%{role: "user", content: "Can you explain LLMs to me?"}],
#        model: model
#      },
#      response_model: LLMExplainer,
#      adapter: adapter,
#      adapter_context: [api_key: api_key]
#    )
# end
# |> IO.inspect(limit: :infinity, printable_limit: :infinity)
