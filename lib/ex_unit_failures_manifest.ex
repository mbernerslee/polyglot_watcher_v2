defmodule PolyglotWatcherV2.ExUnitFailuresManifest.Real do
  def read(file_path) do
    ExUnit.FailuresManifest.read(file_path)
  end
end

defmodule PolyglotWatcherV2.ExUnitFailuresManifest.Fake do
  def read(_file_path), do: %{}
end

defmodule PolyglotWatcherV2.ExUnitFailuresManifest do
  def read(path), do: module().read(path)

  defp module do
    if Application.get_env(:polyglot_watcher_v2, :use_real_file_wrapper_module, true) do
      PolyglotWatcherV2.ExUnitFailuresManifest.Real
    else
      PolyglotWatcherV2.ExUnitFailuresManifest.Fake
    end
  end
end
