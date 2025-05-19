defmodule PolyglotWatcherV2.SystemWrapper do
  def cmd(cmd, args, opts \\ []) do
    System.cmd(cmd, args, opts)
  end

  def get_env(key), do: System.get_env(key)
end
