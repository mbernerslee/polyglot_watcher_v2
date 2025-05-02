defmodule PolyglotWatcherV2.Elixir.Cache.UpdateTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcherV2.Elixir.Cache.{File, LibFile, TestFile}
  alias PolyglotWatcherV2.FileSystem.FileWrapper
  alias PolyglotWatcherV2.Elixir.Cache.Update

  describe "run/4" do
    test "new - reads the lib & test file & adds them to the files" do
      mix_test_output = """
        1) test update/2 parses mix test output, adding failures to the list (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:6
           ** (UndefinedFunctionError) function PolyglotWatcherV2.Failures.update/2 is undefined (module PolyglotWatcherV2.Failures is not available)
           code: Failures.update([], "hi")
           stacktrace:
             PolyglotWatcherV2.Failures.update([], "hi")
             test/elixir_lang_mix_test_test.exs:7: (test)



      Finished in 0.03 seconds (0.03s async, 0.00s sync)
      1 test, 1 failure

      Randomized with seed 529126
      """

      exit_code = 1
      test_path = "test/elixir_lang_mix_test_test.exs:6"

      Mimic.expect(FileWrapper, :read, 2, fn
        "test/elixir_lang_mix_test_test.exs" -> {:ok, "test contents"}
        "lib/elixir_lang_mix_test.ex" -> {:ok, "lib contents"}
      end)

      assert %{
               "test/elixir_lang_mix_test_test.exs" => %File{
                 test: %TestFile{
                   path: "test/elixir_lang_mix_test_test.exs",
                   contents: "test contents",
                   failed_line_numbers: [6]
                 },
                 lib: %LibFile{path: "lib/elixir_lang_mix_test.ex", contents: "lib contents"},
                 mix_test_output: mix_test_output,
                 rank: 1
               }
             } == Update.run(%{}, test_path, mix_test_output, exit_code)
    end

    test "update - reads the lib & test file & adds them to the files" do
      mix_test_output = """
        1) test update/2 parses mix test output, adding failures to the list (PolyglotWatcherV2.FailuresTest)
           test/elixir_lang_mix_test_test.exs:6
           ** (UndefinedFunctionError) function PolyglotWatcherV2.Failures.update/2 is undefined (module PolyglotWatcherV2.Failures is not available)
           code: Failures.update([], "hi")
           stacktrace:
             PolyglotWatcherV2.Failures.update([], "hi")
             test/elixir_lang_mix_test_test.exs:7: (test)



      Finished in 0.03 seconds (0.03s async, 0.00s sync)
      1 test, 1 failure

      Randomized with seed 529126
      """

      exit_code = 1
      test_path = "test/elixir_lang_mix_test_test.exs:6"

      Mimic.expect(FileWrapper, :read, 2, fn
        "test/elixir_lang_mix_test_test.exs" -> {:ok, "new test contents"}
        "lib/elixir_lang_mix_test.ex" -> {:ok, "new lib contents"}
      end)

      old_files = %{
        "test/elixir_lang_mix_test_test.exs" => %File{
          test: %TestFile{
            path: "test/elixir_lang_mix_test_test.exs",
            contents: "old test contents",
            failed_line_numbers: []
          },
          lib: %LibFile{path: "lib/elixir_lang_mix_test.ex", contents: "old lib contents"},
          mix_test_output: nil,
          rank: 1
        }
      }

      expected_new_files = %{
        "test/elixir_lang_mix_test_test.exs" => %File{
          test: %TestFile{
            path: "test/elixir_lang_mix_test_test.exs",
            contents: "new test contents",
            failed_line_numbers: [6]
          },
          lib: %LibFile{path: "lib/elixir_lang_mix_test.ex", contents: "new lib contents"},
          mix_test_output: mix_test_output,
          rank: 1
        }
      }

      assert expected_new_files == Update.run(old_files, test_path, mix_test_output, exit_code)
    end

    test "new tests get rank 1" do
      mix_test_output = "mix test output"
      exit_code = 1

      Mimic.expect(FileWrapper, :read, 2, fn
        "test/new_test.exs" -> {:ok, "new test contents"}
        "lib/new.ex" -> {:ok, "new lib contents"}
      end)

      old_files = %{
        "test/old_one_test.exs" => %File{
          test: %TestFile{
            path: "test/old_one_test.exs",
            contents: "old_one test",
            failed_line_numbers: []
          },
          lib: %LibFile{path: "lib/old_one.ex", contents: "old_one lib"},
          mix_test_output: nil,
          rank: 1
        },
        "test/old_two_test.exs" => %File{
          test: %TestFile{
            path: "test/old_two_test.exs",
            contents: "old_two test",
            failed_line_numbers: []
          },
          lib: %LibFile{path: "lib/old_two.ex", contents: "old_two lib"},
          mix_test_output: nil,
          rank: 2
        }
      }

      assert %{
               "test/new_test.exs" => %File{
                 rank: 1
               },
               "test/old_one_test.exs" => %File{
                 rank: 2
               },
               "test/old_two_test.exs" => %File{
                 rank: 3
               }
             } = Update.run(old_files, "test/new_test.exs", mix_test_output, exit_code)
    end
  end
end
