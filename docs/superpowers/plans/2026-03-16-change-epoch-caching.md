# Change-Epoch Caching Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the MCP `run_tests` tool return cached results when no Elixir files have changed since the last test run, avoiding redundant `mix test` executions.

**Architecture:** A monotonic `change_epoch` integer in the `ElixirCache` GenServer increments on every Elixir file change (via the Determiner). Test run results are stored alongside the epoch at which they ran. When MCP calls `run_tests`, if the stored epoch matches the current epoch, cached results are returned instantly. A separate `last_run_results` map in GenServer state holds run results keyed by exact `MixTestArgs.path` (preserving line numbers and `:all`), keeping this cleanly separated from the existing `cache_items` failure-tracking map.

**Spec deviation:** The spec suggested extending `cache_items` and `CacheItem` to store passed tests. This plan uses a separate `last_run_results` map instead because: (1) `cache_items` keys are normalized file-path strings, but run results need to distinguish `:all`, directory paths, and `{file, line}` tuples; (2) the existing failure-tracking logic (Update, FixedTests, Get) doesn't need to change; (3) no changes needed to `CacheItem` struct or any existing tests. The epoch caching goal is fully achieved without touching the failure-tracking system.

**Tech Stack:** Elixir, GenServer, ExUnit, Mimic

**Spec:** `docs/superpowers/specs/2026-03-16-change-epoch-caching-design.md`

---

## Chunk 1: ElixirCache epoch and run result storage

### Task 1: Add `change_epoch` to ElixirCache GenServer state

**Files:**
- Modify: `lib/elixir/cache.ex` (init, new handle_cast, new handle_call)
- Test: `test/elixir/cache_test.exs`

- [ ] **Step 1: Write the failing test for bump_change_epoch**

In `test/elixir/cache_test.exs`, add a new describe block:

```elixir
describe "bump_change_epoch/1" do
  test "increments the change_epoch in state" do
    assert {:ok, pid} = Cache.start_link([])

    assert :sys.get_state(pid).change_epoch == 0

    Cache.bump_change_epoch(pid)
    # cast is async, use :sys.get_state to force synchronization
    assert :sys.get_state(pid).change_epoch == 1

    Cache.bump_change_epoch(pid)
    assert :sys.get_state(pid).change_epoch == 2
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: FAIL — `change_epoch` key not in state, `bump_change_epoch/1` not defined.

- [ ] **Step 3: Implement change_epoch in GenServer state and bump_change_epoch**

In `lib/elixir/cache.ex`:

Add `change_epoch: 0` to the state map in `init/1` (line 60, inside the `%{}` map):

```elixir
{:ok,
 %{
   status: :loading,
   cache_items: %{},
   running_key: nil,
   same_key_waiters: [],
   queue: [],
   change_epoch: 0
 }, {:continue, :load}}
```

Add the public function (after `await_or_run` around line 51):

```elixir
def bump_change_epoch(pid \\ @process_name) do
  GenServer.cast(pid, :bump_change_epoch)
end
```

Add the handle_cast callback (after the handle_continue block, around line 81):

```elixir
@impl GenServer
def handle_cast(:bump_change_epoch, state) do
  {:noreply, Map.update!(state, :change_epoch, &(&1 + 1))}
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: PASS

- [ ] **Step 5: Write the failing test for get_change_epoch**

```elixir
describe "get_change_epoch/1" do
  test "returns the current change_epoch" do
    assert {:ok, pid} = Cache.start_link([])

    assert 0 == Cache.get_change_epoch(pid)

    Cache.bump_change_epoch(pid)
    _ = :sys.get_state(pid)

    assert 1 == Cache.get_change_epoch(pid)
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: FAIL — `get_change_epoch/1` not defined.

- [ ] **Step 7: Implement get_change_epoch**

In `lib/elixir/cache.ex`, add the public function:

```elixir
def get_change_epoch(pid \\ @process_name) do
  GenServer.call(pid, :get_change_epoch)
end
```

Add the handle_call callback:

```elixir
@impl GenServer
def handle_call(:get_change_epoch, _from, state) do
  {:reply, state.change_epoch, state}
end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: PASS

- [ ] **Step 9: Commit**

```
feat: add change_epoch to ElixirCache with bump and get functions
```

---

### Task 2: Store run results with epoch in Cache.update

**Files:**
- Modify: `lib/elixir/cache.ex` (init state, handle_call for :update)
- Test: `test/elixir/cache_test.exs`

The `last_run_results` map stores test run output keyed by the exact `MixTestArgs.path` value (string, tuple, or `:all`). This is separate from `cache_items` which tracks per-file failure info. This separation is intentional:
- `cache_items` keys are always normalized file-path strings; `last_run_results` keys preserve line numbers and `:all`
- `cache_items` tracks failure state across runs; `last_run_results` tracks the most recent output of a specific `mix test` invocation
- Existing failure-tracking logic (Update, FixedTests, Get) is untouched

- [ ] **Step 1: Write the failing test**

```elixir
describe "update/4 - last_run_results" do
  test "stores the run result with the current epoch" do
    assert {:ok, pid} = Cache.start_link([])

    args = %MixTestArgs{path: "test/cool_test.exs"}
    Cache.update(pid, args, "1 test, 0 failures", 0)

    state = :sys.get_state(pid)

    assert %{
             "test/cool_test.exs" => %{output: "1 test, 0 failures", exit_code: 0, epoch: 0}
           } = state.last_run_results
  end

  test "stores with tuple key when line number is present" do
    assert {:ok, pid} = Cache.start_link([])

    args = %MixTestArgs{path: {"test/cool_test.exs", 42}}
    Cache.update(pid, args, "1 test, 0 failures", 0)

    state = :sys.get_state(pid)

    assert %{
             {"test/cool_test.exs", 42} => %{output: "1 test, 0 failures", exit_code: 0, epoch: 0}
           } = state.last_run_results
  end

  test "stores with :all key" do
    assert {:ok, pid} = Cache.start_link([])

    args = %MixTestArgs{path: :all}
    Cache.update(pid, args, "10 tests, 0 failures", 0)

    state = :sys.get_state(pid)
    assert %{all: %{output: "10 tests, 0 failures", exit_code: 0, epoch: 0}} = state.last_run_results
  end

  test "epoch on stored result reflects the change_epoch at time of update" do
    assert {:ok, pid} = Cache.start_link([])

    Cache.bump_change_epoch(pid)
    Cache.bump_change_epoch(pid)
    _ = :sys.get_state(pid)

    args = %MixTestArgs{path: "test/cool_test.exs"}
    Cache.update(pid, args, "output", 0)

    state = :sys.get_state(pid)
    assert state.last_run_results["test/cool_test.exs"].epoch == 2
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: FAIL — `last_run_results` not in state.

- [ ] **Step 3: Implement last_run_results storage**

In `lib/elixir/cache.ex`:

Add `last_run_results: %{}` to the state map in `init/1`:

```elixir
{:ok,
 %{
   status: :loading,
   cache_items: %{},
   running_key: nil,
   same_key_waiters: [],
   queue: [],
   change_epoch: 0,
   last_run_results: %{}
 }, {:continue, :load}}
```

In the `handle_call({:update, mix_test_args, mix_test_output, exit_code}, ...)` callback, after `cache_items = Update.run(...)` (line 85), add storage of the run result. The `mix_test_args` is already available as a parameter. Extract the path key from it:

Add a private function:

```elixir
defp run_result_key(%MixTestArgs{path: path}), do: path
```

In the existing `handle_call({:update, ...})`, after the `state =` block that handles queue draining (~line 93-117), before `{:reply, :ok, state}`, update `last_run_results`:

```elixir
run_result = %{output: mix_test_output, exit_code: exit_code, epoch: state.change_epoch}
state = put_in(state.last_run_results[run_result_key(mix_test_args)], run_result)

{:reply, :ok, state}
```

Note: You'll need to add `mix_test_args` to the `handle_call` signature. Currently the signature is `handle_call({:update, mix_test_args, mix_test_output, exit_code}, _from, state)` — it already has `mix_test_args`, so this is just using the existing binding.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: PASS

- [ ] **Step 5: Run full test suite to verify no regressions**

Run: `mix test --color`
Expected: All existing tests PASS.

- [ ] **Step 6: Commit**

```
feat: store last_run_results with epoch in ElixirCache
```

---

### Task 3: Add get_cached_result to ElixirCache

**Files:**
- Modify: `lib/elixir/cache.ex`
- Test: `test/elixir/cache_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
describe "get_cached_result/2" do
  test "returns :miss when no cached result exists" do
    assert {:ok, pid} = Cache.start_link([])

    args = %MixTestArgs{path: "test/cool_test.exs"}
    assert :miss == Cache.get_cached_result(pid, args)
  end

  test "returns {:hit, output, exit_code} when epoch matches" do
    assert {:ok, pid} = Cache.start_link([])

    args = %MixTestArgs{path: "test/cool_test.exs"}
    Cache.update(pid, args, "1 test, 0 failures", 0)

    assert {:hit, "1 test, 0 failures", 0} == Cache.get_cached_result(pid, args)
  end

  test "returns :miss when epoch has moved on" do
    assert {:ok, pid} = Cache.start_link([])

    args = %MixTestArgs{path: "test/cool_test.exs"}
    Cache.update(pid, args, "1 test, 0 failures", 0)

    Cache.bump_change_epoch(pid)
    _ = :sys.get_state(pid)

    assert :miss == Cache.get_cached_result(pid, args)
  end

  test "distinguishes between file path and file:line path" do
    assert {:ok, pid} = Cache.start_link([])

    file_args = %MixTestArgs{path: "test/cool_test.exs"}
    line_args = %MixTestArgs{path: {"test/cool_test.exs", 42}}

    Cache.update(pid, file_args, "file output", 0)

    assert {:hit, "file output", 0} == Cache.get_cached_result(pid, file_args)
    assert :miss == Cache.get_cached_result(pid, line_args)
  end

  test "works with :all path" do
    assert {:ok, pid} = Cache.start_link([])

    args = %MixTestArgs{path: :all}
    Cache.update(pid, args, "all output", 0)

    assert {:hit, "all output", 0} == Cache.get_cached_result(pid, args)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: FAIL — `get_cached_result/2` not defined.

- [ ] **Step 3: Implement get_cached_result**

In `lib/elixir/cache.ex`, add the public function:

```elixir
def get_cached_result(pid \\ @process_name, %MixTestArgs{} = mix_test_args) do
  GenServer.call(pid, {:get_cached_result, mix_test_args})
end
```

Add the handle_call:

```elixir
@impl GenServer
def handle_call({:get_cached_result, mix_test_args}, _from, state) do
  key = run_result_key(mix_test_args)

  result =
    case Map.get(state.last_run_results, key) do
      %{epoch: epoch, output: output, exit_code: exit_code}
      when epoch == state.change_epoch ->
        {:hit, output, exit_code}

      _ ->
        :miss
    end

  {:reply, result, state}
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/elixir/cache_test.exs --color`
Expected: PASS

- [ ] **Step 5: Commit**

```
feat: add get_cached_result to ElixirCache for epoch-based cache lookups
```

---

## Chunk 2: Determiner, MixTest, and RunTests integration

### Task 4: Bump change_epoch in Determiner

**Files:**
- Modify: `lib/elixir/determiner.ex`
- Test: `test/elixir/determiner_test.exs`

The `Elixir.Cache` module is already Mimic-copied in `test/test_helper.exs`. The Determiner tests already use Mimic and already alias `Cache`.

- [ ] **Step 1: Write the failing test**

In `test/elixir/determiner_test.exs`, add to the existing `describe "determine_actions/2"` block:

```elixir
test "bumps the change_epoch on the cache" do
  server_state = ServerStateBuilder.build()

  Mimic.expect(Cache, :bump_change_epoch, fn -> :ok end)

  Determiner.determine_actions(@ex_file_path, server_state)

  Mimic.verify!(Cache)
end
```

Note: `Mimic.expect` with a count of 1 (the default) combined with `Mimic.verify!` ensures the function was called exactly once.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/elixir/determiner_test.exs --color`
Expected: FAIL — `bump_change_epoch` was expected to be called but wasn't.

- [ ] **Step 3: Implement the epoch bump in Determiner**

In `lib/elixir/determiner.ex`, add `Cache` to the alias block (line 3-12). Currently it aliases from `PolyglotWatcherV2.Elixir.{...}`. Add `Cache` there:

```elixir
alias PolyglotWatcherV2.Elixir.Cache
```

In `determine_actions/2` (line 25-31), add the bump inside the `if` block, before `by_mode`:

```elixir
def determine_actions(%FilePath{} = file_path, server_state) do
  if file_path.extension in @extensions do
    Cache.bump_change_epoch()
    by_mode(file_path, server_state)
  else
    {:none, server_state}
  end
end
```

- [ ] **Step 4: Add Mimic stub for bump_change_epoch to existing tests**

The new test passes, but other existing `determine_actions` tests fail because they don't expect the `bump_change_epoch` call. Fix this before running.

The existing `determine_actions` tests don't set up a mock for `bump_change_epoch`, so Mimic will reject the unexpected call. Add a `setup` block at the top of the `describe "determine_actions/2"` block:

```elixir
setup do
  Mimic.stub(Cache, :bump_change_epoch, fn -> :ok end)
  :ok
end
```

This stubs `bump_change_epoch` for all tests in the describe block. The explicit `Mimic.expect` in the new test (step 1) will override the stub for that specific test.

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/elixir/determiner_test.exs --color`
Expected: ALL PASS

- [ ] **Step 6: Run full test suite**

Run: `mix test --color`
Expected: All pass. Check that no other tests call `determine_actions` without a `bump_change_epoch` mock.

- [ ] **Step 7: Commit**

```
feat: bump change_epoch in Elixir.Determiner on every file change
```

---

### Task 5: Add use_cache option to MixTest.run

**Files:**
- Modify: `lib/elixir/mix_test.ex`
- Test: `test/elixir/mix_test_test.exs`

`MixTest.run/1` currently takes `(mix_test_args)` and `MixTest.run/2` takes `(mix_test_args, server_state)`. We're making the second arg always a keyword list of options. The `server_state` variant becomes `run(args, server_state: state)`.

Options:
- `use_cache: :no_cache` (default) — always run tests
- `use_cache: :cached` — check `Cache.get_cached_result` first
- `server_state: state` — return `{exit_code, state}` instead of `{output, exit_code}`

- [ ] **Step 1: Write the failing test for use_cache: :cached hit**

In `test/elixir/mix_test_test.exs`, add a new describe block:

```elixir
describe "run/2 with use_cache" do
  test "use_cache: :cached returns cached result on hit" do
    mix_test_args = %MixTestArgs{path: "test/cool_test.exs"}

    Mimic.expect(Cache, :get_cached_result, fn ^mix_test_args ->
      {:hit, "1 test, 0 failures", 0}
    end)

    assert {"1 test, 0 failures", 0} == MixTest.run(mix_test_args, use_cache: :cached)
  end

  test "use_cache: :cached falls through to run on miss" do
    mix_test_args = %MixTestArgs{path: "test/cool_test.exs"}
    mock_output = mock_mix_test_output()

    Mimic.expect(Cache, :get_cached_result, fn ^mix_test_args -> :miss end)
    Mimic.expect(Cache, :await_or_run, fn ^mix_test_args -> :not_running end)

    Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs --color" ->
      {mock_output, 0}
    end)

    Mimic.expect(Cache, :update, fn ^mix_test_args, ^mock_output, 0 -> :ok end)

    assert {mock_output, 0} == MixTest.run(mix_test_args, use_cache: :cached)
  end

  test "use_cache: :no_cache always runs (does not check cache)" do
    mix_test_args = %MixTestArgs{path: "test/cool_test.exs"}
    mock_output = mock_mix_test_output()

    # No expect for get_cached_result — it should NOT be called
    Mimic.expect(Cache, :await_or_run, fn ^mix_test_args -> :not_running end)

    Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs --color" ->
      {mock_output, 0}
    end)

    Mimic.expect(Cache, :update, fn ^mix_test_args, ^mock_output, 0 -> :ok end)

    assert {mock_output, 0} == MixTest.run(mix_test_args, use_cache: :no_cache)
  end

  test "with server_state option returns {exit_code, server_state}" do
    mix_test_args = %MixTestArgs{path: "test/cool_test.exs"}
    mock_output = mock_mix_test_output()
    server_state = ServerStateBuilder.build()

    Mimic.expect(Cache, :await_or_run, fn ^mix_test_args -> :not_running end)

    Mimic.expect(ShellCommandRunner, :run, fn "mix test test/cool_test.exs --color" ->
      {mock_output, 0}
    end)

    Mimic.expect(Cache, :update, fn ^mix_test_args, ^mock_output, 0 -> :ok end)

    assert {0, ^server_state} = MixTest.run(mix_test_args, server_state: server_state)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/elixir/mix_test_test.exs --color`
Expected: FAIL — `run/2` doesn't accept keyword list.

- [ ] **Step 3: Implement the new run/2 with opts**

Replace the two existing `run` functions in `lib/elixir/mix_test.ex` with:

```elixir
def run(%MixTestArgs{} = mix_test_args, opts \\ []) do
  use_cache = Keyword.get(opts, :use_cache, :no_cache)
  server_state = Keyword.get(opts, :server_state)

  {output, exit_code, from_cache?} =
    case use_cache do
      :cached ->
        case Cache.get_cached_result(mix_test_args) do
          {:hit, output, exit_code} -> {output, exit_code, true}
          :miss -> run_tests(mix_test_args)
        end

      :no_cache ->
        run_tests(mix_test_args)
    end

  unless from_cache?, do: put_result_message(exit_code)

  if server_state do
    {exit_code, server_state}
  else
    {output, exit_code}
  end
end

defp run_tests(mix_test_args) do
  {output, exit_code} =
    case Cache.await_or_run(mix_test_args) do
      {:ok, result} -> result
      :not_running -> execute(mix_test_args)
    end

  {output, exit_code, false}
end
```

- [ ] **Step 4: Run tests to verify new tests pass**

Run: `mix test test/elixir/mix_test_test.exs --color`
Expected: New tests PASS. Old `run/1` tests should still pass (opts defaults to `[]`). Old `run/2` tests will FAIL because they pass `server_state` directly instead of as a keyword.

- [ ] **Step 5: Update existing run/2 tests to use keyword opts**

In `test/elixir/mix_test_test.exs`, the `describe "run/2"` tests pass `server_state` as the second arg. Update them to use `server_state: server_state`:

```elixir
# Before:
assert {0, server_state} == MixTest.run(mix_test_args, server_state)

# After:
assert {0, server_state} == MixTest.run(mix_test_args, server_state: server_state)
```

Update all three tests in the `describe "run/2"` block.

- [ ] **Step 6: Run tests to verify all pass**

Run: `mix test test/elixir/mix_test_test.exs --color`
Expected: ALL PASS

- [ ] **Step 7: Update ActionsExecutor callers to use keyword opts**

The callers in `lib/actions_executor.ex` pass `server_state` as the second arg. Update them to keyword form at the same time as the signature change so the codebase stays compilable.

In `lib/actions_executor.ex`, line 127:

```elixir
# Before:
MixTest.run(%MixTestArgs{path: :all}, server_state)

# After:
MixTest.run(%MixTestArgs{path: :all}, server_state: server_state)
```

Line 131:

```elixir
# Before:
MixTest.run(mix_test_args, server_state)

# After:
MixTest.run(mix_test_args, server_state: server_state)
```

- [ ] **Step 8: Run full test suite**

Run: `mix test --color`
Expected: ALL PASS

- [ ] **Step 9: Commit**

```
feat: add use_cache option to MixTest.run and update all callers
```

---

### Task 6: Update RunTests.call to use cache

**Files:**
- Modify: `lib/mcp/tools/run_tests.ex`
- Test: `test/mcp/tools/run_tests_test.exs`

- [ ] **Step 1: Write the failing test for cache hit**

In `test/mcp/tools/run_tests_test.exs`, add:

```elixir
test "returns cached result when cache hit" do
  args = %MixTestArgs{path: "test/cool_test.exs"}

  Mimic.expect(Cache, :get_cached_result, fn ^args ->
    {:hit, "1 test, 0 failures", 0}
  end)

  result = RunTests.call(%{"test_path" => "test/cool_test.exs"})
  decoded = Jason.decode!(result)

  assert decoded["exit_code"] == 0
  assert decoded["output"] == "1 test, 0 failures"
  assert decoded["test_path"] == "test/cool_test.exs"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/mcp/tools/run_tests_test.exs --color`
Expected: FAIL — `get_cached_result` was expected to be called but wasn't.

- [ ] **Step 3: Update RunTests.call to pass use_cache: :cached**

In `lib/mcp/tools/run_tests.ex`, change `call/1`:

```elixir
def call(arguments) do
  mix_test_args = build_args(arguments)

  ActionsExecutor.execute({:puts, :cyan, "MCP request received..."})

  {output, exit_code} = MixTest.run(mix_test_args, use_cache: :cached)

  Jason.encode!(%{
    exit_code: exit_code,
    output: strip_ansi(output),
    test_path: format_path(mix_test_args.path)
  })
end
```

- [ ] **Step 4: Run test to verify the new test passes**

Run: `mix test test/mcp/tools/run_tests_test.exs --color`
Expected: New test PASSES. Existing tests will FAIL because they mock `Cache.await_or_run` but now `MixTest.run` checks `Cache.get_cached_result` first (since `use_cache: :cached`).

- [ ] **Step 5: Update existing RunTests tests to mock get_cached_result**

Each existing test that goes through the full run path needs a `get_cached_result` mock returning `:miss`, since the MCP path now checks cache first.

Add to the beginning of each existing `call/1` test:

```elixir
Mimic.expect(Cache, :get_cached_result, fn _ -> :miss end)
```

For the "returns awaited result when test is already running" test, same addition — `get_cached_result` returns `:miss`, then `await_or_run` returns the awaited result.

- [ ] **Step 6: Run tests to verify all pass**

Run: `mix test test/mcp/tools/run_tests_test.exs --color`
Expected: ALL PASS

- [ ] **Step 7: Run full test suite**

Run: `mix test --color`
Expected: ALL PASS

- [ ] **Step 8: Commit**

```
feat: MCP run_tests uses epoch-based cache to skip redundant test runs
```

---

## Chunk 3: Verification

### Task 7: Full integration verification

- [ ] **Step 1: Run the complete test suite**

Run: `mix test --color`
Expected: ALL PASS

- [ ] **Step 2: Compile with warnings-as-errors**

Run: `MIX_ENV=test mix compile --warnings-as-errors --force`
Expected: No warnings, clean compile.

- [ ] **Step 3: Final commit (if any remaining changes)**

Only if there are uncommitted fixes from steps 1-2.
