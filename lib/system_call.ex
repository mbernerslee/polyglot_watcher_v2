defmodule PolyglotWatcherV2.SystemCall do
  def cmd(cmd, args, opts \\ []) do
    System.cmd(cmd, args, opts)
  end
end
