# Dynamic MCP Port Allocation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded MCP port 4848 with OS-assigned ephemeral ports, enabling multiple watcher instances across directories without port conflicts.

**Architecture:** The Elixir app starts Bandit on port 0 (OS picks a free port), discovers the assigned port via `ThousandIsland.listener_info/1`, and writes it to `.polyglot_watcher_v2/config.json`. A new `MCP.Startup` GenServer manages this lifecycle (start, config write, shutdown cleanup). The bash proxy reads the port from the config file via `jq` and re-reads on connection failure. An `MCP.InstanceChecker` module prevents duplicate MCP servers per directory by verifying existing instances via PID + MCP ping.

**Tech Stack:** Elixir/OTP (GenServer, Bandit, ThousandIsland), Bash, jq

**Spec:** `docs/superpowers/specs/2026-03-16-dynamic-mcp-port-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/file_system.ex` | Modify | Add `rename/2` to FileWrapper (Real, Fake, delegator) |
| `lib/mcp/config_file.ex` | Create | Read/write/delete `.polyglot_watcher_v2/config.json` |
| `lib/mcp/instance_checker.ex` | Create | Liveness check: OS PID alive + MCP ping |
| `lib/mcp/startup.ex` | Create | GenServer managing MCP lifecycle (start Bandit, write config, cleanup on shutdown) |
| `lib/polyglot_watcher_v2.ex` | Modify | Replace `mcp_children/0` with `MCP.Startup` child spec, remove `port_available?/1` and `@mcp_default_port` |
| `config/config.exs` | Modify | Remove `mcp_port: 4848` |
| `mcp_stdio_proxy` | Modify | Read port from config file via `jq`, re-read on connection failure |
| `.gitignore` | Modify | Add `.polyglot_watcher_v2/` |
| `test_e2e_mcp` | Modify | Two-phase wait: poll for config file, read port, poll for port readiness |
| `test/mcp/config_file_test.exs` | Create | Unit tests for ConfigFile |
| `test/mcp/instance_checker_test.exs` | Create | Unit tests for InstanceChecker |
| `test/test_helper.exs` | Modify | Add `Mimic.copy(Req)` |

---

## Chunk 1: Config File Foundation

### Task 1: Add `rename/2` to FileWrapper

**Files:**
- Modify: `lib/file_system.ex` (three modules inside: Real, Fake, delegator)

- [ ] **Step 1: Add `rename/2` to `FileWrapper.Real`**

In `lib/file_system.ex`, inside the `PolyglotWatcherV2.FileSystem.FileWrapper.Real` module, add:

```elixir
def rename(source, destination), do: File.rename(source, destination)
```

- [ ] **Step 2: Add `rename/2` to `FileWrapper.Fake`**

In `lib/file_system.ex`, inside the `PolyglotWatcherV2.FileSystem.FileWrapper.Fake` module, add:

```elixir
def rename(_source, _destination), do: :ok
```

- [ ] **Step 3: Add `rename/2` to `FileWrapper` delegator**

In `lib/file_system.ex`, inside the `PolyglotWatcherV2.FileSystem.FileWrapper` module, add:

```elixir
def rename(source, destination), do: module().rename(source, destination)
```

- [ ] **Step 4: Run tests to verify nothing broke**

Run: `mix test` (via MCP `run_tests` tool if available)
Expected: All existing tests pass (no tests for rename yet — it's just wiring).

- [ ] **Step 5: Commit**

```bash
git add lib/file_system.ex
git commit -m "feat: add rename/2 to FileWrapper for atomic file writes"
```

---

### Task 2: Create MCP.ConfigFile module

**Files:**
- Create: `lib/mcp/config_file.ex`
- Create: `test/mcp/config_file_test.exs`

The config file lives at `.polyglot_watcher_v2/config.json` relative to the current working directory. Format: `{"mcp_tcp_port": <int>, "pid": <int>}`. Uses `FileWrapper` for all file I/O so tests can mock it.

- [ ] **Step 1: Write the failing tests**

Create `test/mcp/config_file_test.exs`:

```elixir
defmodule PolyglotWatcherV2.MCP.ConfigFileTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.ConfigFile
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  describe "write/2" do
    test "creates directory, writes tmp file, renames atomically" do
      Mimic.expect(FileWrapper, :mkdir_p, fn ".polyglot_watcher_v2" -> :ok end)

      Mimic.expect(FileWrapper, :write, fn ".polyglot_watcher_v2/config.json.tmp", content ->
        decoded = Jason.decode!(content)
        assert decoded == %{"mcp_tcp_port" => 5123, "pid" => 12345}
        :ok
      end)

      Mimic.expect(FileWrapper, :rename, fn
        ".polyglot_watcher_v2/config.json.tmp", ".polyglot_watcher_v2/config.json" -> :ok
      end)

      assert :ok = ConfigFile.write(5123, 12345)
    end
  end

  describe "read/0" do
    test "reads and parses config file" do
      Mimic.expect(FileWrapper, :read, fn ".polyglot_watcher_v2/config.json" ->
        {:ok, ~s({"mcp_tcp_port": 5123, "pid": 12345})}
      end)

      assert {:ok, %{"mcp_tcp_port" => 5123, "pid" => 12345}} = ConfigFile.read()
    end

    test "returns :error when file doesn't exist" do
      Mimic.expect(FileWrapper, :read, fn ".polyglot_watcher_v2/config.json" ->
        {:error, :enoent}
      end)

      assert :error = ConfigFile.read()
    end

    test "returns :error when file contains invalid JSON" do
      Mimic.expect(FileWrapper, :read, fn ".polyglot_watcher_v2/config.json" ->
        {:ok, "not valid json"}
      end)

      assert :error = ConfigFile.read()
    end
  end

  describe "delete/0" do
    test "removes config file" do
      Mimic.expect(FileWrapper, :rm_rf, fn ".polyglot_watcher_v2/config.json" -> {:ok, []} end)

      assert ConfigFile.delete()
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/mcp/config_file_test.exs`
Expected: Compilation error — `PolyglotWatcherV2.MCP.ConfigFile` module does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/mcp/config_file.ex`:

```elixir
defmodule PolyglotWatcherV2.MCP.ConfigFile do
  alias PolyglotWatcherV2.FileSystem.FileWrapper

  @dir ".polyglot_watcher_v2"
  @file "config.json"
  @tmp_file "config.json.tmp"

  def path, do: Path.join(@dir, @file)
  defp tmp_path, do: Path.join(@dir, @tmp_file)

  def write(port, pid) do
    content = Jason.encode!(%{"mcp_tcp_port" => port, "pid" => pid})

    with :ok <- FileWrapper.mkdir_p(@dir),
         :ok <- FileWrapper.write(tmp_path(), content),
         :ok <- FileWrapper.rename(tmp_path(), path()) do
      :ok
    end
  end

  def read do
    with {:ok, content} <- FileWrapper.read(path()),
         {:ok, decoded} <- Jason.decode(content) do
      {:ok, decoded}
    else
      _ -> :error
    end
  end

  def delete do
    FileWrapper.rm_rf(path())
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/mcp/config_file_test.exs`
Expected: 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/mcp/config_file.ex test/mcp/config_file_test.exs
git commit -m "feat: add MCP.ConfigFile for reading/writing dynamic port config"
```

---

## Chunk 2: Instance Checker and Startup

### Task 3: Create MCP.InstanceChecker module

**Files:**
- Create: `lib/mcp/instance_checker.ex`
- Create: `test/mcp/instance_checker_test.exs`
- Modify: `test/test_helper.exs` (add `Mimic.copy(Req)`)

Checks whether an existing watcher instance is alive by: (1) verifying the OS PID is running via `kill -0`, and (2) sending an MCP ping to the port and validating the response contains `"jsonrpc":"2.0"` and a `"result"` key. Both must pass — this guards against OS PID reuse.

Uses `ShellCommandRunner` (already Mimic-copied) for the PID check and `Req` for the HTTP ping.

- [ ] **Step 1: Add `Mimic.copy(Req)` to test_helper.exs**

In `test/test_helper.exs`, add before `ExUnit.start()`:

```elixir
Mimic.copy(Req)
```

- [ ] **Step 2: Write the failing tests**

Create `test/mcp/instance_checker_test.exs`:

```elixir
defmodule PolyglotWatcherV2.MCP.InstanceCheckerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias PolyglotWatcherV2.MCP.InstanceChecker
  alias PolyglotWatcherV2.ShellCommandRunner

  describe "alive?/2" do
    test "returns true when PID is running and port responds to MCP ping" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345" -> {"", 0} end)

      Mimic.expect(Req, :post, fn "http://localhost:5123/mcp", opts ->
        assert opts[:json] == %{"jsonrpc" => "2.0", "id" => 0, "method" => "ping"}
        assert opts[:receive_timeout] == 2_000
        assert opts[:retry] == false
        {:ok, %{status: 200, body: %{"jsonrpc" => "2.0", "result" => %{}}}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == true
    end

    test "returns false when PID is not running" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 99999" ->
        {"kill: (99999) - No such process", 1}
      end)

      assert InstanceChecker.alive?(99999, 5123) == false
    end

    test "returns false when PID is running but port doesn't respond" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end

    test "returns false when port responds with non-MCP response" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"not" => "mcp"}}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end

    test "returns false when port responds with non-200 status" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 500, body: "Internal Server Error"}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end

    test "returns false when request times out" do
      Mimic.expect(ShellCommandRunner, :run, fn "kill -0 12345" -> {"", 0} end)

      Mimic.expect(Req, :post, fn _url, _opts ->
        {:error, %Req.TransportError{reason: :timeout}}
      end)

      assert InstanceChecker.alive?(12345, 5123) == false
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/mcp/instance_checker_test.exs`
Expected: Compilation error — `PolyglotWatcherV2.MCP.InstanceChecker` module does not exist.

- [ ] **Step 4: Write the implementation**

Create `lib/mcp/instance_checker.ex`:

```elixir
defmodule PolyglotWatcherV2.MCP.InstanceChecker do
  alias PolyglotWatcherV2.ShellCommandRunner

  def alive?(pid, port) do
    pid_running?(pid) && mcp_responds?(port)
  end

  defp pid_running?(pid) do
    {_output, exit_code} = ShellCommandRunner.run("kill -0 #{pid}")
    exit_code == 0
  end

  defp mcp_responds?(port) do
    case Req.post("http://localhost:#{port}/mcp",
           json: %{"jsonrpc" => "2.0", "id" => 0, "method" => "ping"},
           receive_timeout: 2_000,
           connect_options: [timeout: 2_000],
           retry: false
         ) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        body["jsonrpc"] == "2.0" && Map.has_key?(body, "result")

      _ ->
        false
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/mcp/instance_checker_test.exs`
Expected: 6 tests, 0 failures.

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass (existing tests unaffected).

- [ ] **Step 7: Commit**

```bash
git add lib/mcp/instance_checker.ex test/mcp/instance_checker_test.exs test/test_helper.exs
git commit -m "feat: add MCP.InstanceChecker for detecting existing watcher instances"
```

---

### Task 4: Create MCP.Startup GenServer and wire into app

**Files:**
- Create: `lib/mcp/startup.ex`
- Modify: `lib/polyglot_watcher_v2.ex`
- Modify: `config/config.exs` (remove `mcp_port: 4848`)

The `MCP.Startup` GenServer manages the MCP server lifecycle:
- On `init`: checks for an existing instance (via ConfigFile + InstanceChecker), starts Bandit on port 0 if none found, extracts port via `ThousandIsland.listener_info/1`, writes config file.
- On `terminate`: deletes config file (cleanup on graceful shutdown).
- Traps exits so `terminate` is called on supervisor shutdown and Bandit crashes.
- Returns `:ignore` from `init` when another instance is alive (supervisor skips this child, file watching continues).

No unit tests for this module — it's orchestration code tested via `test_e2e_mcp`.

- [ ] **Step 1: Create MCP.Startup GenServer**

Create `lib/mcp/startup.ex`:

```elixir
defmodule PolyglotWatcherV2.MCP.Startup do
  use GenServer

  alias PolyglotWatcherV2.MCP.{ConfigFile, InstanceChecker}
  alias PolyglotWatcherV2.Puts

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Process.flag(:trap_exit, true)

    case check_and_start() do
      {:ok, state} -> {:ok, state}
      :skip -> :ignore
    end
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    ConfigFile.delete()
    :ok
  end

  defp check_and_start do
    case ConfigFile.read() do
      {:ok, %{"pid" => pid, "mcp_tcp_port" => port}} ->
        if InstanceChecker.alive?(pid, port) do
          Puts.on_new_line(
            "MCP server not started — another instance already active " <>
              "for PID #{pid} on port #{port}",
            :yellow
          )

          :skip
        else
          do_start()
        end

      _ ->
        do_start()
    end
  end

  defp do_start do
    Application.ensure_all_started(:bandit)

    with {:ok, bandit_pid} <-
           Bandit.start_link(
             plug: PolyglotWatcherV2.MCP.PlugRouter,
             port: 0,
             startup_log: false,
             thousand_island_options: [num_acceptors: 1]
           ),
         {:ok, {_addr, port}} <- ThousandIsland.listener_info(bandit_pid) do
      os_pid = System.pid() |> String.to_integer()
      ConfigFile.write(port, os_pid)
      {:ok, %{bandit_pid: bandit_pid, port: port}}
    else
      error ->
        Puts.on_new_line(
          "MCP server failed to start: #{inspect(error)}. " <>
            "File watching still works, but MCP clients won't be able to connect.",
          :red
        )

        :skip
    end
  end
end
```

- [ ] **Step 2: Replace startup logic in `lib/polyglot_watcher_v2.ex`**

Replace the entire file contents with:

```elixir
defmodule PolyglotWatcherV2 do
  alias PolyglotWatcherV2.Server
  alias PolyglotWatcherV2.Elixir.Cache, as: ElixirCache

  def main(command_line_args \\ []) do
    run(command_line_args)
    :timer.sleep(:infinity)
  end

  def run(command_line_args) do
    # order is important. Server sometimes waits for ElixirCache to be up, so ElixirCache must be first
    children =
      [ElixirCache.child_spec(), Server.child_spec(command_line_args)] ++ mcp_children()

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp mcp_children do
    if Application.get_env(:polyglot_watcher_v2, :start_mcp, true) do
      [{PolyglotWatcherV2.MCP.Startup, []}]
    else
      []
    end
  end
end
```

This removes: `@mcp_default_port 4848`, `port_available?/1`, the old `mcp_children/0` with its port-binding logic, and the `Puts` alias (no longer needed here).

- [ ] **Step 3: Remove `mcp_port` from `config/config.exs`**

In `config/config.exs`, delete this line:

```elixir
config :polyglot_watcher_v2, mcp_port: 4848
```

- [ ] **Step 4: Run tests to verify nothing broke**

Run: `mix test`
Expected: All existing tests pass. The `start_mcp: false` test config means `MCP.Startup` is never added as a child in tests.

- [ ] **Step 5: Commit**

```bash
git add lib/mcp/startup.ex lib/polyglot_watcher_v2.ex config/config.exs
git commit -m "feat: dynamic MCP port via MCP.Startup GenServer, remove hardcoded port 4848"
```

---

## Chunk 3: Scripts, Cleanup, and Verification

### Task 5: Update mcp_stdio_proxy for dynamic port discovery

**Files:**
- Modify: `mcp_stdio_proxy`

Replace hardcoded `MCP_URL` with dynamic config file reading via `jq`. The proxy reads `.polyglot_watcher_v2/config.json` on startup and re-reads on connection failure (handles watcher restarts changing the port). Falls back to direct `mix test` if no config or watcher unreachable (existing behavior preserved).

**Dependency:** `jq` must be installed. If missing, config reading fails silently and the proxy uses fallbacks.

- [ ] **Step 1: Replace the MCP_URL initialization at the top of `mcp_stdio_proxy`**

Replace:

```bash
MCP_URL="${MCP_URL:-http://localhost:4848/mcp}"
```

With:

```bash
CONFIG_FILE=".polyglot_watcher_v2/config.json"

# Read MCP URL from config file written by the watcher
read_mcp_url() {
  if [ -f "$CONFIG_FILE" ]; then
    local port
    port=$(jq -r '.mcp_tcp_port // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$port" ]; then
      echo "http://localhost:${port}/mcp"
      return 0
    fi
  fi
  return 1
}

MCP_URL=""
if url=$(read_mcp_url); then
  MCP_URL="$url"
fi
```

- [ ] **Step 2: Update the main loop for retry-on-failure**

Replace the main `while` loop body (from `while IFS= read -r line; do` to `done`) with:

```bash
while IFS= read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue

  echo "RECV: $line" >> "$LOG"

  # If we have no URL yet, try reading config
  if [ -z "$MCP_URL" ]; then
    if url=$(read_mcp_url); then
      MCP_URL="$url"
      echo "DISCOVERED: $MCP_URL" >> "$LOG"
    fi
  fi

  # Check if it's a notification (no "id" field) - we don't need the response
  if ! echo "$line" | grep -q '"id"'; then
    if [ -n "$MCP_URL" ]; then
      curl -s -o /dev/null --max-time 2 -X POST "$MCP_URL" \
        -H 'Content-Type: application/json' \
        -d "$line" 2>/dev/null
    fi
    echo "NOTIF: (no response)" >> "$LOG"
    continue
  fi

  # It's a request - try to forward to the watcher
  sent=false
  if [ -n "$MCP_URL" ]; then
    response=$(curl -s --max-time 30 -X POST "$MCP_URL" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      -d "$line" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
      echo "SEND: $response" >> "$LOG"
      echo "$response"
      sent=true
    fi
  fi

  # On failure, re-read config and retry (handles watcher restart with new port)
  if [ "$sent" = false ]; then
    if new_url=$(read_mcp_url); then
      if [ "$new_url" != "$MCP_URL" ]; then
        MCP_URL="$new_url"
        echo "RETRY: new URL=$MCP_URL" >> "$LOG"
        response=$(curl -s --max-time 30 -X POST "$MCP_URL" \
          -H 'Content-Type: application/json' \
          -H 'Accept: application/json' \
          -d "$line" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$response" ]; then
          echo "SEND: $response" >> "$LOG"
          echo "$response"
          sent=true
        fi
      fi
    fi
  fi

  # Watcher is not reachable - generate fallback response
  if [ "$sent" = false ]; then
    req_id=$(extract_id "$line")
    method=$(extract_method "$line")

    echo "FALLBACK ($method): watcher unreachable" >> "$LOG"

    case "$method" in
      initialize)
        response=$(fallback_initialize "$req_id")
        ;;
      ping)
        response=$(fallback_ping "$req_id")
        ;;
      tools/list)
        response=$(fallback_tools_list "$req_id")
        ;;
      tools/call)
        tool_name=$(extract_tool_name "$line")
        if [ "$tool_name" = "run_tests" ]; then
          test_path=$(extract_test_path "$line")
          line_number=$(extract_line_number "$line")
          response=$(fallback_run_tests "$req_id" "$test_path" "$line_number")
        else
          response=$(fallback_error "$req_id")
        fi
        ;;
      *)
        response=$(fallback_error "$req_id")
        ;;
    esac

    echo "SEND: $response" >> "$LOG"
    echo "$response"
  fi
done
```

- [ ] **Step 3: Verify the proxy script is syntactically valid**

Run:

```bash
bash -n mcp_stdio_proxy
```

Expected: No output (no syntax errors).

- [ ] **Step 4: Commit**

```bash
git add mcp_stdio_proxy
git commit -m "feat: proxy reads MCP port from config file via jq, retries on failure"
```

---

### Task 6: Cleanup and update test_e2e_mcp

**Files:**
- Modify: `.gitignore`
- Modify: `test_e2e_mcp`

- [ ] **Step 1: Add `.polyglot_watcher_v2/` to `.gitignore`**

Append to `.gitignore`:

```
.polyglot_watcher_v2/
```

- [ ] **Step 2: Update `test_e2e_mcp` for dynamic port discovery**

Replace the port setup and wait logic at the top of `test_e2e_mcp`. The hardcoded `MCP_PORT=4848` line and the port-polling loop are replaced with a two-phase wait: first poll for the config file to appear, then read the port from it, then poll for port readiness.

Replace:

```bash
MCP_PORT=4848
WATCHER_BIN="$SCRIPT_DIR/polyglot_watcher_v2"
```

With:

```bash
WATCHER_BIN="$SCRIPT_DIR/polyglot_watcher_v2"
CONFIG_FILE=".polyglot_watcher_v2/config.json"
```

Replace the entire port-waiting block (from `# Wait for MCP port to be ready` through the `if ! kill -0` check after the loop) with:

```bash
# Phase 1: Wait for config file to appear
info "Waiting for config file at $CONFIG_FILE..."
for i in $(seq 1 30); do
  if [ -f "$CONFIG_FILE" ]; then
    break
  fi
  if ! kill -0 "$WATCHER_PID" 2>/dev/null; then
    fail "Watcher process died during startup"
  fi
  sleep 0.5
done

if [ ! -f "$CONFIG_FILE" ]; then
  fail "Config file never appeared at $CONFIG_FILE"
fi

MCP_PORT=$(jq -r '.mcp_tcp_port' "$CONFIG_FILE")
if [ -z "$MCP_PORT" ] || [ "$MCP_PORT" = "null" ]; then
  fail "Config file exists but mcp_tcp_port is missing or null"
fi
info "Discovered MCP port: $MCP_PORT"

# Phase 2: Wait for MCP server on discovered port
info "Waiting for MCP server on port $MCP_PORT..."
MCP_READY=false
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w '' "http://localhost:$MCP_PORT/mcp" --max-time 1 -X POST -H 'Content-Type: application/json' -d '{}' 2>/dev/null; then
    MCP_READY=true
    break
  fi
  if ! kill -0 "$WATCHER_PID" 2>/dev/null; then
    fail "Watcher process died during startup"
  fi
  sleep 0.5
done

if [ "$MCP_READY" = false ]; then
  fail "MCP server never became ready on port $MCP_PORT"
fi
```

Also add config file cleanup to the `cleanup()` function:

```bash
cleanup() {
  if [[ -n "$WATCHER_PID" ]]; then
    info "Stopping watcher (pid $WATCHER_PID)"
    kill "$WATCHER_PID" 2>/dev/null || true
    wait "$WATCHER_PID" 2>/dev/null || true
  fi
  rm -f ".polyglot_watcher_v2/config.json" 2>/dev/null || true
}
```

- [ ] **Step 3: Verify test_e2e_mcp syntax**

Run:

```bash
bash -n test_e2e_mcp
```

Expected: No output (no syntax errors).

- [ ] **Step 4: Commit**

```bash
git add .gitignore test_e2e_mcp
git commit -m "chore: gitignore .polyglot_watcher_v2/, update e2e test for dynamic port"
```

---

### Task 7: Full verification

- [ ] **Step 1: Run the full unit test suite**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 2: Build a release and run the e2e test**

Run:

```bash
MIX_ENV=prod mix release --overwrite && ./test_e2e_mcp
```

Expected: All 7 e2e tests pass, with the port being dynamically discovered from the config file.

- [ ] **Step 3: Verify config file is created and cleaned up**

During the e2e test, the config file `.polyglot_watcher_v2/config.json` should:
- Appear after watcher startup (containing `mcp_tcp_port` and `pid`)
- Be deleted after the watcher is stopped (cleanup function or graceful shutdown)

- [ ] **Step 4: Manual smoke test — run the watcher and check config**

Run:

```bash
./build_and_run_dirty &
sleep 3
cat .polyglot_watcher_v2/config.json
# Should show: {"mcp_tcp_port":<some-port>,"pid":<watcher-pid>}
kill %1
sleep 1
ls .polyglot_watcher_v2/config.json
# Should show: file not found (cleaned up on shutdown)
```
