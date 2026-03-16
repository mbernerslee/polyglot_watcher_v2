# Change-Epoch Caching for MCP Test Results

## Problem

The MCP `run_tests` tool always executes `mix test`, even when the watcher has already run the exact same tests and nothing has changed since. This wastes time — especially when Claude calls `run_tests` shortly after a file save that the watcher already handled.

The ideal solution (MCP server-push) is blocked because Claude Code doesn't support receiving server-initiated MCP notifications. This design is a workaround: make `run_tests` smart enough to return cached results when nothing has changed.

## Design

### Core concept: change_epoch

A monotonically increasing integer in `ElixirCache` GenServer state. Every time an Elixir file changes (detected at the determiner level), the epoch increments. Test results are stored tagged with the epoch at which they ran. If the epoch hasn't changed since a cached result was stored, that result is still valid.

### Components

#### 1. ElixirCache state change

Add `change_epoch: 0` to the GenServer state map in `init/1`.

New public functions (all follow existing `pid \\ @process_name` pattern):

- `bump_change_epoch/0` — a cast (not call) that increments the epoch. Fire-and-forget because the determiner shouldn't block.
- `get_cached_result/1` — synchronous call taking a `MixTestArgs`. Returns `{:hit, output, exit_code}` if a cached result exists for this test path AND its stored epoch equals the current `change_epoch`. Returns `:miss` otherwise. Both values live in the same GenServer state, so the comparison is atomic.

`Cache.update/3` (the existing function called after every test run) is extended to tag stored results with the current `change_epoch`.

#### 2. Elixir.Determiner bumps epoch

In `determine_actions/2`, inside the existing `if file_path.extension in @extensions` block, before the `by_mode` call:

```elixir
Cache.bump_change_epoch()
```

This ensures every Elixir file change (regardless of mode) bumps the epoch immediately.

Testing: mock `Cache.bump_change_epoch/0` via Mimic in determiner tests (Cache is already Mimic-copied in test_helper.exs). The actual bump logic is tested in cache tests with per-test GenServer instances.

#### 3. MixTest.run gets a use_cache option

`MixTest.run/1` gains an optional keyword list:

- `MixTest.run(mix_test_args, use_cache: true)` — checks `Cache.get_cached_result` first. On `:hit`, returns cached results without running. On `:miss`, runs tests as normal.
- `MixTest.run(mix_test_args)` — defaults to `use_cache: false`, always runs tests (current behavior, unchanged).

This keeps the cache-awareness at the `MixTest` level rather than in MCP-specific code.

#### 4. RunTests.call/1 passes use_cache: true

The MCP tool passes the option through:

```elixir
{output, exit_code} = MixTest.run(mix_test_args, use_cache: true)
```

File-save-triggered runs continue calling `MixTest.run/1` without the option, so they always execute.

### Edge cases

**Race: file changes while tests run.** Determiner bumps epoch to N, watcher starts tests. Another save bumps epoch to N+1. Tests finish, stored with epoch N. Next MCP call sees epoch N+1 vs cached N — miss, re-runs. Correct.

**MCP call while watcher is mid-test.** Epoch already bumped, so cache miss. `MixTest.run` calls `Cache.await_or_run` which joins the in-flight run. No double-run.

**`:all` vs specific path.** Cache keys are already normalized by `normalize_key`. `:all` is cached separately from specific paths. An epoch bump invalidates everything equally — the intentional coarseness tradeoff.

**File save always runs.** Because the watcher path calls `MixTest.run(args)` without `use_cache: true`, file saves always trigger a real test run.

### What changes

| File | Change |
|---|---|
| `lib/elixir/cache.ex` | Add `change_epoch` to state, add `bump_change_epoch`, `get_cached_result` |
| `lib/elixir/determiner.ex` | Add `Cache.bump_change_epoch()` in `determine_actions/2` |
| `lib/elixir/mix_test.ex` | Add `use_cache` option to `run`, check cache on `use_cache: true` |
| `lib/mcp/tools/run_tests.ex` | Pass `use_cache: true` to `MixTest.run` |
| `test/elixir/cache_test.exs` | Tests for `bump_change_epoch` and `get_cached_result` |
| `test/elixir/determiner_test.exs` | Mock `Cache.bump_change_epoch/0`, verify it's called |
| `test/elixir/mix_test_test.exs` | Test `use_cache` option (hit and miss paths) |
| `test/mcp/tools/run_tests_test.exs` | Update to reflect `use_cache: true` being passed |

### What doesn't change

- The watcher's file-change-triggered test flow — always runs, unchanged
- The existing mutex/dedup in ElixirCache — unchanged
- Action tree traversal — unchanged, epoch bump is a side effect outside the tree
