defmodule PolyglotWatcherV2.GitDiff do
  alias PolyglotWatcherV2.{FileSystem, Puts, SystemCall}

  @old "/tmp/polyglot_watcher_v2_old"
  @new "/tmp/polyglot_watcher_v2_new"

  # TODO write this
  # Plan is that this will
  # - read the file
  # - search it
  # - generate replacement contents (replace "search" with "replace")
  # - write original & replacement to separate tmp files
  # - run git diff --no-index to generate a diff
  # - write the diff to the terminal
  # - rm -rf the /tmp/polyglot_watcher_v2 dir at the end and recreate it at the start as the real step one (so that every time we execute this we clean up after ourselves)

  def run(file_path, search, replace, server_state) do
    {:ok, _contents} = FileSystem.read(file_path)

    FileSystem.write(@old, search)
    FileSystem.write(@new, replace)

    # exit_code = 1 when there's a diff, otherwise 0. makes error handling tricky...
    {std_out, _exit_code} =
      SystemCall.cmd("git", ["diff", "--no-index", "--color", @old, @new])

    Puts.on_new_line_unstyled(std_out)

    FileSystem.rm_rf(@old)
    FileSystem.rm_rf(@new)

    {0, server_state}
  end
end
