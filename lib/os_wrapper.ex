defmodule PolyglotWatcherV2.OSWrapper.Fake do
  def type, do: {:unix, :linux}
end

defmodule PolyglotWatcherV2.OSWrapper.Real do
  def type,
    do:
      :os.type()
      |> IO.inspect()
end

defmodule PolyglotWatcherV2.OSWrapper do
  def type, do: module().type()

  defp module do
    if Application.get_env(:polyglot_watcher_v2, :use_real_os_module, true) do
      PolyglotWatcherV2.OSWrapper.Real
    else
      PolyglotWatcherV2.OSWrapper.Fake
    end
  end
end
