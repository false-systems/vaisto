defmodule Vaisto.ErrorFormatter do
  @moduledoc """
  Formats compiler errors in a Rust-style diagnostic format.

  Produces human-friendly error messages like:

      error: type mismatch
        --> test.va:3:6
        |
      3 |     (+ 2 :bad)
        |          ^^^^ expected Int, found Atom
        |
  """

  @type error :: %{
    message: String.t(),
    file: String.t() | nil,
    line: pos_integer(),
    col: pos_integer(),
    span_length: pos_integer(),
    hint: String.t() | nil
  }

  @doc """
  Formats an error with source context in Rust diagnostic style.

  ## Parameters
    - error: Map with :message, :line, :col, :file, optional :span_length, :hint
    - source: The original source code string

  ## Example

      iex> error = %{message: "Type mismatch", line: 3, col: 6, file: "test.va", span_length: 4}
      iex> source = "(+ 1\\n   (+ 2\\n      :bad))"
      iex> ErrorFormatter.format(error, source)
      "error: Type mismatch\\n  --> test.va:3:6\\n..."
  """
  @spec format(error(), String.t()) :: String.t()
  def format(error, source) do
    lines = String.split(source, "\n")
    line_content = Enum.at(lines, error.line - 1, "")

    # Build the formatted output
    [
      format_header(error),
      format_location(error),
      format_source_line(error, line_content),
      format_pointer(error, line_content),
      format_hint(error)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  @doc """
  Formats multiple errors with source context.
  """
  @spec format_all([error()], String.t()) :: String.t()
  def format_all(errors, source) do
    errors
    |> Enum.map(&format(&1, source))
    |> Enum.join("\n\n")
  end

  @doc """
  Parses a legacy error string like "file:line:col: message" into structured format.
  Returns nil if the string doesn't match the expected format.
  """
  @spec parse_legacy_error(String.t()) :: error() | nil
  def parse_legacy_error(error_string) do
    cond do
      # Format: "file:line:col: message"
      match = Regex.run(~r/^([^:]+):(\d+):(\d+):\s*(.+)$/, error_string) ->
        [_, file, line, col, message] = match
        %{
          message: message,
          file: file,
          line: String.to_integer(line),
          col: String.to_integer(col),
          span_length: estimate_span_length(message),
          hint: nil
        }

      # Format: "line:col: message"
      match = Regex.run(~r/^(\d+):(\d+):\s*(.+)$/, error_string) ->
        [_, line, col, message] = match
        %{
          message: message,
          file: nil,
          line: String.to_integer(line),
          col: String.to_integer(col),
          span_length: estimate_span_length(message),
          hint: nil
        }

      true ->
        nil
    end
  end

  # Format the error header line
  defp format_header(error) do
    IO.ANSI.format([:red, :bright, "error", :reset, ": ", error.message])
    |> IO.iodata_to_binary()
  end

  # Format the location line: " --> file:line:col"
  defp format_location(error) do
    location = case error.file do
      nil -> "#{error.line}:#{error.col}"
      file -> "#{file}:#{error.line}:#{error.col}"
    end

    IO.ANSI.format([:blue, :bright, "  --> ", :reset, location])
    |> IO.iodata_to_binary()
  end

  # Format the source line with line number gutter
  defp format_source_line(error, line_content) do
    line_num = Integer.to_string(error.line)
    padding = String.duplicate(" ", String.length(line_num))

    [
      IO.ANSI.format([:blue, :bright, "#{padding} |", :reset]) |> IO.iodata_to_binary(),
      IO.ANSI.format([:blue, :bright, "#{line_num} |", :reset, " ", line_content])
      |> IO.iodata_to_binary()
    ]
    |> Enum.join("\n")
  end

  # Format the pointer line showing where the error is
  defp format_pointer(error, line_content) do
    line_num = Integer.to_string(error.line)
    gutter_width = String.length(line_num)

    # Calculate visible offset (handle tabs)
    prefix = String.slice(line_content, 0, error.col - 1)
    visual_offset = visual_length(prefix)

    # Build the pointer
    span = Map.get(error, :span_length, 1)
    pointer = String.duplicate("^", max(span, 1))

    spacing = String.duplicate(" ", visual_offset)

    IO.ANSI.format([
      :blue, :bright, String.duplicate(" ", gutter_width), " | ",
      :reset, spacing,
      :red, :bright, pointer, :reset
    ])
    |> IO.iodata_to_binary()
  end

  # Format optional hint
  defp format_hint(%{hint: nil}), do: nil
  defp format_hint(%{hint: hint}) do
    IO.ANSI.format([:blue, :bright, "  = ", :cyan, "hint", :reset, ": ", hint])
    |> IO.iodata_to_binary()
  end

  # Calculate visual length accounting for tabs
  defp visual_length(str) do
    str
    |> String.graphemes()
    |> Enum.reduce(0, fn
      "\t", acc -> acc + 4 - rem(acc, 4)  # Tab stops every 4 chars
      _, acc -> acc + 1
    end)
  end

  # Try to estimate span length from error message
  # This is a heuristic - better to have explicit spans
  defp estimate_span_length(message) do
    cond do
      # "Type mismatch at argument 2" - point at the argument
      message =~ ~r/argument \d+/ -> 4

      # Messages mentioning specific atoms like ":bad"
      match = Regex.run(~r/:(\w+)/, message) ->
        [_, atom] = match
        String.length(atom) + 1  # Include the colon

      # Default
      true -> 1
    end
  end
end
