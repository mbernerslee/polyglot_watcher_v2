defmodule PolyglotWatcherV2.DetermineTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.{Determine, ServerStateBuilder}

  describe "actions/2" do
    test "given :ignore, returns no actions" do
      server_state = ServerStateBuilder.build()
      assert :none == Determine.actions(:ignore)
    end
  end
end
