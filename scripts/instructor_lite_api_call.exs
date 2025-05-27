#!/usr/bin/env elixir

Mix.install([{:req, "~> 0.5.0"}, {:instructor_lite, "~> 0.3.0"}])

InstructorLite.instruct(
  %{
    messages: [%{role: "user", content: "Can you explain LLMs to me?"}],
    model: "claude-3-5-sonnet-20240620"
  },
  response_model: %{tldr: :string, long_version: :string},
  adapter: InstructorLite.Adapters.Anthropic,
  adapter_context: [api_key: System.get_env("ANTHROPIC_API_KEY")]
)
|> IO.inspect(limit: :infinity, printable_limit: :infinity)
