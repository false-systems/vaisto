# Test script for LSP hover
#
# Usage: mix run test_lsp.exs

defmodule LSPTester do
  def run do
    # Test source
    source = "(defn add [x :int] :int (+ x 1))"

    # Parse and typecheck
    IO.puts("Testing source: #{source}")

    ast = Vaisto.Parser.parse(source, file: "test.va")
    IO.puts("Parsed AST: #{inspect(ast)}")

    result = Vaisto.TypeChecker.check(ast)
    IO.puts("Type check result: #{inspect(result)}")

    # Test hover
    alias Vaisto.LSP.Hover

    # Test token finding
    IO.puts("\n--- Token finding tests ---")
    test_positions = [
      {1, 1},   # (
      {1, 2},   # d
      {1, 7},   # a (in add)
      {1, 10},  # space
      {1, 11},  # [
      {1, 12},  # x
    ]

    for {line, col} <- test_positions do
      token_result = Hover.token_at(source, line, col)
      IO.puts("token_at(#{line}, #{col}) = #{inspect(token_result)}")
    end

    # Test hover
    IO.puts("\n--- Hover tests ---")
    for {line, col} <- test_positions do
      hover_result = Hover.get_hover(source, line, col, "test.va")
      IO.puts("get_hover(#{line}, #{col}) = #{inspect(hover_result)}")
    end
  end
end

LSPTester.run()
