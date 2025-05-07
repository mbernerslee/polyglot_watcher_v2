defmodule PolyglotWatcherV2.Elixir.MixTestNextTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.ActionsExecutor
  alias PolyglotWatcherV2.Elixir.Cache
  alias PolyglotWatcherV2.Elixir.MixTestNext
  alias PolyglotWatcherV2.ServerStateBuilder

  describe "run/2" do
    test "with a cache hit & the test passes" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"

      Mimic.expect(Cache, :get, fn this_test_path ->
        assert this_test_path == test_path
        {:ok, {test_path, 1}}
      end)

      Mimic.expect(ActionsExecutor, :execute, 3, fn
        {:puts, :magenta, "Running mix test test/cool_test.exs:1"}, server_state ->
          {0, server_state}

        {:mix_test, "test/cool_test.exs:1"}, server_state ->
          {0, server_state}

        :put_sarcastic_success, server_state ->
          {0, server_state}
      end)

      assert {{:mix_test, :passed}, server_state} == MixTestNext.run(test_path, server_state)
    end

    test "with a cache miss return error" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"

      Mimic.expect(Cache, :get, fn _ ->
        {:error, :not_found}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      assert {{:cache, :miss}, server_state} == MixTestNext.run(test_path, server_state)
    end

    test "with a cache hit & the test fails" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"

      Mimic.expect(Cache, :get, fn _ ->
        {:ok, {test_path, 1}}
      end)

      Mimic.expect(ActionsExecutor, :execute, 3, fn
        {:puts, :magenta, "Running mix test test/cool_test.exs:1"}, server_state ->
          {0, server_state}

        {:mix_test, "test/cool_test.exs:1"}, server_state ->
          {2, server_state}

        :put_insult, server_state ->
          {0, server_state}
      end)

      assert {{:mix_test, :failed}, server_state} == MixTestNext.run(test_path, server_state)
    end

    test "with a cache hit & the test errors" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"

      Mimic.expect(Cache, :get, fn _ ->
        {:ok, {test_path, 1}}
      end)

      Mimic.expect(ActionsExecutor, :execute, 2, fn
        {:puts, :magenta, "Running mix test test/cool_test.exs:1"}, server_state ->
          {0, server_state}

        {:mix_test, "test/cool_test.exs:1"}, server_state ->
          {1, server_state}
      end)

      assert {{:mix_test, :error}, server_state} == MixTestNext.run(test_path, server_state)
    end
  end

  describe "run/1" do
    test "with a cache hit, runs mix test <test_path> --max-failures 1" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"
      line_number = 1

      Mimic.expect(Cache, :get, fn _ ->
        {:ok, {test_path, line_number}}
      end)

      Mimic.expect(ActionsExecutor, :execute, 3, fn
        {:puts, :magenta, "Running mix test test/cool_test.exs --max-failures 1"}, server_state ->
          {0, server_state}

        {:mix_test, "test/cool_test.exs --max-failures 1"}, server_state ->
          {0, server_state}

        :put_sarcastic_success, server_state ->
          {0, server_state}
      end)

      assert {{:mix_test, :passed}, server_state} == MixTestNext.run(server_state)
    end

    test "with a cache hit, runs mix test <test_path> --max-failures 1 and the test fails" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"
      line_number = 1

      Mimic.expect(Cache, :get, fn :latest ->
        {:ok, {test_path, line_number}}
      end)

      Mimic.expect(ActionsExecutor, :execute, 3, fn
        {:puts, :magenta, "Running mix test test/cool_test.exs --max-failures 1"}, server_state ->
          {0, server_state}

        {:mix_test, "test/cool_test.exs --max-failures 1"}, server_state ->
          {2, server_state}

        :put_insult, server_state ->
          {0, server_state}
      end)

      assert {{:mix_test, :failed}, server_state} == MixTestNext.run(server_state)
    end

    test "with a cache hit, runs mix test <test_path> --max-failures 1 and the test errors" do
      server_state = ServerStateBuilder.build()
      test_path = "test/cool_test.exs"
      line_number = 1

      Mimic.expect(Cache, :get, fn :latest ->
        {:ok, {test_path, line_number}}
      end)

      Mimic.expect(ActionsExecutor, :execute, 2, fn
        {:puts, :magenta, "Running mix test test/cool_test.exs --max-failures 1"}, server_state ->
          {0, server_state}

        {:mix_test, "test/cool_test.exs --max-failures 1"}, server_state ->
          {1, server_state}
      end)

      assert {{:mix_test, :error}, server_state} == MixTestNext.run(server_state)
    end

    test "with a cache miss return error" do
      server_state = ServerStateBuilder.build()

      Mimic.expect(Cache, :get, fn :latest ->
        {:error, :not_found}
      end)

      Mimic.reject(&ActionsExecutor.execute/2)

      assert {{:cache, :miss}, server_state} == MixTestNext.run(server_state)
    end
  end
end
