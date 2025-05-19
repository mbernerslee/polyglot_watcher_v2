defmodule PolyglotWatcherV2.InstructorLite.Fake do
  def instruct(_params, _opts), do: {:error, :default_fake_mock_error}
end

defmodule PolyglotWatcherV2.InstructorLiteWrapper do
  def instruct(params, opts), do: module().instruct(params, opts)

  defp module do
    if Application.get_env(:polyglot_watcher_v2, :use_real_instructor_lite, true) do
      InstructorLite
    else
      PolyglotWatcherV2.InstructorLite.Fake
    end
  end
end
