# Change-Epoch Caching for MCP Test Results

## Problem

The MCP `run_tests` tool always executes `mix test`, even when the watcher has already run the exact same tests and nothing has changed since. This wastes time — especially when Claude calls `run_tests` shortly after a file save that the watcher already handled.

The ideal solution (MCP server-push) is blocked because Claude Code doesn't support receiving server-initiated MCP notifications. This design is a workaround: make `run_tests` smart enough to return cached results when nothing has changed.

## Design

### Core concept: change_epoch

A monotonically increasing integer in `ElixirCache` GenServer state. Every time an Elixir file changes (detected at the determiner level), the epoch increments. Test results are stored tagged with the epoch at which they ran. If the epoch hasn't changed since a cached result was stored, that result is still valid.

### Run result storage: `last_run_results` (separate from `cache_items`)

Run results are stored in a new `last_run_results` map in GenServer state, keyed by exact `MixTestArgs.path` (string, tuple with line number, or `:all`). This is separate from the existing `cache_items` failure-tracking map because:
- `cache_items` keys are normalized file-path strings; run results need to distinguish `:all`, directory paths, and `{file, line}` tuples
- `cache_items` tracks failure state across runs; run results track the most recent output of a specific `mix test` invocation
- Existing failure-tracking logic (Update, FixedTests, Get) remains untouched

### Components

#### 1. ElixirCache state changes

Add to the GenServer state map in `init/1`:
- `change_epoch: 0`
- `last_run_results: %{}`

New public functions (all follow existing `pid \\ @process_name` pattern):

- `bump_change_epoch/0` — a cast (not call) that increments the epoch. Fire-and-forget because the determiner shouldn't block.
- `get_cached_result/1` — synchronous call taking a `MixTestArgs`. Returns `{:hit, output, exit_code}` if a result exists in `last_run_results` for this path AND its stored epoch equals the current `change_epoch`. Returns `:miss` otherwise. Both values live in the same GenServer state, so the comparison is atomic.

`Cache.update/4` (the existing function called after every test run) is extended to also store the run result in `last_run_results` tagged with the current `change_epoch`.

#### 2. Elixir.Determiner bumps epoch

In `determine_actions/2`, inside the existing `if file_path.extension in @extensions` block, before the `by_mode` call:

```elixir
Cache.bump_change_epoch()
```

This ensures every Elixir file change (regardless of mode) bumps the epoch immediately.

Testing: mock `Cache.bump_change_epoch/0` via Mimic in determiner tests (Cache is already Mimic-copied in test_helper.exs). A `setup` block in the `describe "determine_actions/2"` stubs it for all tests; the specific verification test uses `Mimic.expect` to override.

#### 3. MixTest.run gets a mandatory opts keyword list

`MixTest.run/2`'s second argument becomes a keyword list. The old `run(args, server_state)` call sites change to `run(args, server_state: server_state)`.

Options:
- `use_cache: :no_cache` (default) — always run tests
- `use_cache: :cached` — check `Cache.get_cached_result` first; on `:hit`, return cached results without running; on `:miss`, run as normal
- `server_state: state` — return `{exit_code, state}` instead of `{output, exit_code}`

On cache hit, `put_result_message` (the sarcastic success/insult message) is skipped — no test ran, so no terminal feedback.

#### 4. RunTests.call/1 passes use_cache: :cached

The MCP tool passes the option through:

```elixir
{output, exit_code} = MixTest.run(mix_test_args, use_cache: :cached)
```

File-save-triggered runs continue calling `MixTest.run(args, server_state: server_state)` without `use_cache`, so they always execute.

### Edge cases

**Race: file changes while tests run.** Determiner bumps epoch to N, watcher starts tests. Another save bumps epoch to N+1. Tests finish, stored with epoch N. Next MCP call sees epoch N+1 vs cached N — miss, re-runs. Correct.

**MCP call while watcher is mid-test.** Epoch already bumped, so cache miss. `MixTest.run` calls `Cache.await_or_run` which joins the in-flight run. No double-run.

**`:all` vs specific path.** Run result keys use the raw `MixTestArgs.path` value. `:all` is cached separately from specific paths. An epoch bump invalidates everything equally — the intentional coarseness tradeoff.

**File save always runs.** Because the watcher path doesn't pass `use_cache: :cached`, file saves always trigger a real test run.

**Narrow cast/call race.** `bump_change_epoch` is a cast (async). In theory, an MCP `get_cached_result` call could arrive at the GenServer mailbox before the cast from a concurrent determiner. In practice, this window is sub-microsecond and the consequence is merely returning a soon-to-be-stale cache hit. The next call would miss. Acceptable tradeoff.

### What changes

| File | Change |
|---|---|
| `lib/elixir/cache.ex` | Add `change_epoch` and `last_run_results` to state, add `bump_change_epoch`, `get_cached_result`, store run results in update |
| `lib/elixir/determiner.ex` | Add `Cache.bump_change_epoch()` in `determine_actions/2` |
| `lib/elixir/mix_test.ex` | Change `run/2` second arg to keyword opts, add `use_cache` support, skip sarcastic message on cache hit |
| `lib/actions_executor.ex` | Update `MixTest.run` call sites to keyword opts |
| `lib/mcp/tools/run_tests.ex` | Pass `use_cache: :cached` to `MixTest.run` |
| `test/elixir/cache_test.exs` | Tests for `bump_change_epoch`, `get_cached_result`, `last_run_results` storage |
| `test/elixir/determiner_test.exs` | Stub `Cache.bump_change_epoch/0` in setup, verify it's called |
| `test/elixir/mix_test_test.exs` | Test `use_cache` option (hit and miss paths), update existing tests to keyword opts |
| `test/mcp/tools/run_tests_test.exs` | Test cache hit path, add `get_cached_result` mock to existing tests |

### What doesn't change

- The watcher's file-change-triggered test flow — always runs, unchanged
- The existing `cache_items` failure-tracking system — untouched
- The existing mutex/dedup in ElixirCache — unchanged
- Action tree traversal — unchanged, epoch bump is a side effect outside the tree
- `CacheItem` struct — unchanged
- `Update`, `FixedTests`, `Get` modules — unchanged
