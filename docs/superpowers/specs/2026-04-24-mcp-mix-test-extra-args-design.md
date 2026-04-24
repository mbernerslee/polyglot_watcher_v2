# MCP `mix_test` Extra Args — Design

## Problem

The `mix_test` MCP tool currently accepts only `test_path` and `line_number`. Users (and the LLM) sometimes want to run diagnostic flags like `--slowest 5`, `--trace`, or `--seed 42` via the tool, but today the tool rejects them because `MixTestArgs` is a tightly-structured struct with no room for arbitrary flags.

The struct is deliberately locked down (see its module doc): `Cache.FixedTests.determine/2` infers "which tests passed" from `path + exit_code`, which breaks if flags change which tests actually ran (`--failed`, `--stale`, `--only TAG`, etc.). Naively passing arbitrary flags through would corrupt the watcher's cache.

## Goal

Let the MCP tool pass arbitrary extra flags to `mix test`, while keeping the watcher's cache correct. Unknown flags are treated as worst-case.

## Non-goals

- Exposing extra-args to the normal user-typed modes (`ex d`, `ex ra`, etc.). This is MCP-only.
- Rejecting flags. We accept everything; safety comes from cache bypass, not validation.

## Design

### MCP tool surface

Add an `extra_args` parameter to the `mix_test` MCP tool:

- Type: `array<string>`. An array (not a single whitespace-separated string) avoids quoting ambiguity and matches the shape the LLM will naturally produce.
- Default: `[]`.
- Description explicitly discourages routine use — the LLM should only pass `extra_args` for ad-hoc diagnostics requested by the human user.

Example call: `{"test_path": "test/foo_test.exs", "extra_args": ["--slowest", "5"]}`.

### Data model

Add `extra_args: [String.t()]` field to `MixTestArgs`, default `[]`.

Two new responsibilities for `MixTestArgs`:

1. `to_shell_command/1` appends `extra_args` tokens verbatim after `path` and `max_failures`.
2. `category/1` returns `:safe` or `:paranoid`.

### Categorization

`category(args)` logic:

1. If `args.extra_args == []` → `:safe` (existing behavior preserved).
2. Else, for every token in `extra_args` starting with `--`:
   - Strip any `=value` suffix (so `--slowest=5` is treated as `--slowest`).
   - Check membership in the Safe allowlist.
3. If all `--` tokens are in the allowlist → `:safe`. Otherwise → `:paranoid`.

Non-`--` tokens (values for preceding flags) are passed through unchanged and do not affect the category decision.

#### Safe allowlist

These flags do not change which tests run and do not change how `exit_code == 0` maps to "all tests under `path` passed":

- `--trace` — verbose output, forces sync execution.
- `--slowest` — prints the slowest-N report.
- `--slowest-modules` — same, by module.
- `--color` / `--no-color` — output formatting.
- `--formatter` — output formatter module.
- `--preload-modules` — compile-time behavior.
- `--max-requires` — compile-time parallelism.
- `--seed` — reorders tests. Same semantics as the watcher's own runs (which also use arbitrary seeds). Exit 0 still means "all tests in path passed for this seed".
- `--cover` — runs coverage analysis alongside; tests run identically.

#### Paranoid fallback

Anything not in the allowlist (including unrecognized flags) triggers paranoid mode. Notably-paranoid flags and why:

- `--failed`, `--stale` — only a subset of tests runs.
- `--only TAG`, `--exclude TAG`, `--include TAG` — tag filtering changes what runs.
- `--timeout` — can flip pass/fail on slow tests.
- `--raise`, `--warnings-as-errors` — exit code reflects warnings, not test outcomes.
- `--exit-status` — overrides the failure exit code, breaking `exit_code == 0` semantics.
- `--repeat-until-failure` — reveals flakiness; a pass here doesn't match normal semantics.
- `--partitions`, `--partitions-total` — runs only one partition.
- `--breakpoints` — interactive debugging.
- `--max-failures` — already modeled as a struct field; should not appear in `extra_args` (if it does, treated paranoid).

### Cache behavior

Five cache touchpoints. The table shows behavior per scenario:

| Scenario | #1 cache read (`get_cached_result`) | #2 in-flight dedup (`await_or_run`) | #3 record failures (`Cache.Update.combine`) | #4 mark fixed (`FixedTests.determine`) | #5 store output (`maybe_store_run_result`) |
|---|---|---|---|---|---|
| Normal watcher run | ✓ | ✓ | ✓ | ✓ | ✓ |
| MCP, `extra_args = []` | ✓ | ✓ | ✓ | ✓ | ✓ |
| MCP + Safe flags | ✗ | ✗ | ✓ | ✓ | ✗ |
| MCP + Paranoid flags | ✗ | ✗ | ✓ | ✗ | ✗ |

Rationale for each column:

- **#1 / #2**: When `extra_args != []`, the cached or in-flight result reflects a different command than what the LLM asked for. Returning it would hand back output that doesn't match the requested flags (e.g. no `--trace` output when `--trace` was requested). Always skip these when any extra args are present.
- **#3**: Recording failures is always additive ground truth. If a test actually failed during the run, it's a real failure regardless of what flags were in effect. Keep this in all scenarios.
- **#4**: This is the column the Safe/Paranoid split controls. Safe flags preserve the "exit 0 on `path` means all tests under `path` passed" semantic, so `FixedTests.determine` is correct. Paranoid flags break that semantic.
- **#5**: Mirrors the existing `max_failures` precedent — don't pollute the path-keyed result cache with flag-specific output, because a later flag-less MCP call or watcher run would get the wrong output.

### Implementation touchpoints

- **`lib/mcp/tools/run_tests.ex`** — accept `extra_args` from the MCP input, thread it into the `MixTestArgs` the tool builds.
- **`lib/elixir/mix_test_args.ex`** — new `extra_args` field; extend `to_shell_command/1` to append it; new `category/1` function; module attribute holding the Safe allowlist.
- **`lib/elixir/mix_test.ex`** — when `extra_args != []`, bypass `Cache.get_cached_result` and `Cache.await_or_run`, and run `execute/2` directly.
- **`lib/elixir/cache.ex`** — extend the `maybe_store_run_result` guard so it also skips storage when `extra_args != []` (joining the existing `max_failures: nil` guard).
- **`lib/elixir/cache/fixed_tests.ex`** — add a clause that returns `nil` when `MixTestArgs.category(args) == :paranoid`.

### Implementation order — strict outside-in TDD

Start at the top of the call stack with a small number of high-level tests, drive the implementation down through every layer to make them green, then descend adding denser coverage at each lower module. The number of tests increases as we move down; the lowest module (`MixTestArgs`) has the most exhaustive coverage because it carries the most branching logic.

Each step follows the red-green cycle: write a failing test first, then make it pass. No implementation code precedes a failing test.

#### Step 1 — Top tier: MCP tool (few tests)

File: `test/mcp/tools/run_tests_test.exs`.

A small set of end-to-end-shaped tests that exercise the feature through the MCP tool entry point. These fail until the full vertical slice is implemented, so passing them drives changes in `run_tests.ex`, `mix_test_args.ex`, `mix_test.ex`, `cache.ex`, `cache/update.ex`, and `cache/fixed_tests.ex` all at once.

Tests:

1. Tool call with `extra_args: []` behaves identically to today (regression).
2. Tool call with a Safe flag (e.g. `["--slowest", "5"]`) produces a shell command that includes the flag and returns the new flags in the response.
3. Tool call with a Paranoid flag (e.g. `["--only", "integration"]`) on `exit_code == 0` does NOT clear the file's entry from `Cache.FixedTests`.
4. Tool call with `extra_args != []` bypasses the stored-output cache read — the real command is executed even when a cached result exists for the same path.

After step 1, the feature is functionally complete. The remaining steps add confidence and cover edge cases.

#### Step 2 — Middle tier: orchestration and cache wiring

Files: `test/elixir/mix_test_test.exs`, `test/elixir/cache_test.exs`, `test/elixir/cache/update_test.exs`, `test/elixir/cache/fixed_tests_test.exs`.

Tests (roughly one or two per behavior):

- `mix_test_test.exs` — `extra_args != []` skips `Cache.get_cached_result`; skips `Cache.await_or_run` dedup and runs independently.
- `cache_test.exs` — `maybe_store_run_result` skips storing when `extra_args != []` (extends the existing `max_failures: nil` guard).
- `cache/update_test.exs` — with paranoid args and `exit_code == 0`, the file's cache entry is not cleared; failures in the output are still recorded.
- `cache/fixed_tests_test.exs` — returns `nil` when `MixTestArgs.category(args) == :paranoid`, regardless of exit code.

#### Step 3 — Bottom tier: `MixTestArgs` (most coverage)

File: `test/elixir/mix_test_args_test.exs`.

Exhaustive unit tests for the pure logic:

- `category/1`:
  - `:safe` for empty `extra_args`.
  - `:safe` for each individual flag in the Safe allowlist.
  - `:safe` for each Safe flag in `--flag=value` form.
  - `:safe` for multiple Safe flags together, including with interleaved value tokens.
  - `:paranoid` for each explicitly-Paranoid flag called out in the design.
  - `:paranoid` for an unknown flag not in either list.
  - `:paranoid` for a mix of one Safe and one Paranoid flag.
  - Non-`--` tokens (values) alone don't flip the category.
- `to_shell_command/1`:
  - Appends `extra_args` tokens verbatim after `path` and `max_failures`.
  - Preserves ordering.
  - Works with empty `extra_args` (unchanged from today).
  - Works in combination with `path`, `{path, line}`, `:all`, and `max_failures`.

## Open questions / future work

- Growing the Safe allowlist: if usage reveals common diagnostic flags that are missing, add them to the module attribute in `MixTestArgs`. No user-facing configuration — the allowlist lives in source.
- MCP tool description currently does not enumerate the Safe allowlist to the LLM. If the LLM frequently passes Paranoid flags unnecessarily, we can add hints to the tool description later.
