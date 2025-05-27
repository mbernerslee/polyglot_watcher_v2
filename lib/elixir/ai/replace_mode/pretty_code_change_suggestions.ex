defmodule PolyglotWatcherV2.Elixir.AI.ReplaceMode.PrettyCodeChangeSuggestions do
  @magenta IO.ANSI.magenta()
  @reset IO.ANSI.reset()
  @gray "\e[90m"
  @line "────────────────────────────────────────────────────────────"

  def generate(suggestions) do
    """
    #{header()}
    #{suggestions(suggestions)}
    #{footer()}
    """
  end

  defp suggestions(suggestions) do
    Enum.map_join(suggestions, "\n#{@gray}#{@line}#{@reset}\n\n", &suggestion/1)
  end

  defp suggestion(suggestion) do
    %{
      index: index,
      path: path,
      git_diff: git_diffs,
      explanation: explanation
    } = suggestion

    """
    #{@gray}#{index}) 📁 #{path}#{@reset}

    #{git_diffs(git_diffs)}

    #{@gray}🔎 #{explanation}#{@reset}
    """
  end

  defp git_diffs(git_diffs) do
    git_diffs
    |> Enum.map_join("\n\n", &git_diff/1)
    |> String.trim_trailing()
  end

  defp git_diff(%{start_line: start_line, end_line: end_line, diff: diff}) do
    String.trim_trailing("""
    #{@gray}Lines #{start_line} - #{end_line}#{@reset}
    #{diff}
    """)
  end

  defp header do
    """
    #{@magenta}#{@line}
    🤖 AI Suggestions
    #{@line}#{@reset}
    """
  end

  defp footer do
    String.trim_trailing("""
    #{@magenta}#{@line}
    🎯 Choose your action:
       y          Apply all suggestions
       n          Skip all suggestions
       1,2,3      Apply specific suggestions (comma-separated)
    #{@line}#{@reset}
    """)
  end
end
