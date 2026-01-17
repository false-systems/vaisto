defmodule Vaisto.Errors do
  @moduledoc """
  Error catalog with codes and constructors for all Vaisto compiler errors.

  Each error has a unique code (E001-E999) that can be used for documentation lookup.
  Use `vaistoc --explain E001` to get detailed information about an error.

  ## Error Categories
  - E001-E099: Type errors
  - E100-E199: Name resolution errors
  - E200-E299: Syntax errors
  - E300-E399: Process/concurrency errors
  """

  alias Vaisto.Error

  # ============================================================================
  # Type Errors (E001-E099)
  # ============================================================================

  @doc "Type mismatch between expected and actual types"
  def type_mismatch(expected, actual, opts \\ []) do
    Error.new("E001", "type mismatch",
      Keyword.merge(opts, [expected: expected, actual: actual])
    )
  end

  @doc "List elements have inconsistent types"
  def list_type_mismatch(expected, actual, opts \\ []) do
    Error.new("E002", "list elements must have the same type",
      Keyword.merge(opts, [expected: expected, actual: actual])
    )
  end

  @doc "If/match branches have different types"
  def branch_type_mismatch(branch1_type, branch2_type, opts \\ []) do
    Error.new("E003", "branch types must match",
      Keyword.merge(opts, [
        expected: branch1_type,
        actual: branch2_type,
        note: "all branches of a conditional must return the same type"
      ])
    )
  end

  @doc "Return type doesn't match declared type"
  def return_type_mismatch(declared, inferred, opts \\ []) do
    Error.new("E004", "return type mismatch",
      Keyword.merge(opts, [
        expected: declared,
        actual: inferred,
        hint: "the function body returns a different type than declared"
      ])
    )
  end

  @doc "Wrong number of arguments to function"
  def arity_mismatch(func_name, expected, actual, opts \\ []) do
    Error.new("E005", "wrong number of arguments",
      Keyword.merge(opts, [
        note: "`#{func_name}` takes #{expected} argument(s), but #{actual} were provided"
      ])
    )
  end

  @doc "Operation requires specific type"
  def invalid_operand(operation, expected, actual, opts \\ []) do
    Error.new("E006", "invalid operand type",
      Keyword.merge(opts, [
        expected: expected,
        actual: actual,
        note: "`#{operation}` requires #{Error.format_type(expected)}"
      ])
    )
  end

  @doc "cons type mismatch between element and list"
  def cons_type_mismatch(elem_type, list_type, opts \\ []) do
    Error.new("E007", "cons type mismatch",
      Keyword.merge(opts, [
        expected: list_type,
        actual: elem_type,
        hint: "element type must match list element type"
      ])
    )
  end

  @doc "Operation expects a list"
  def not_a_list(operation, actual, opts \\ []) do
    Error.new("E008", "expected a list",
      Keyword.merge(opts, [
        expected: {:list, :any},
        actual: actual,
        note: "`#{operation}` operates on lists"
      ])
    )
  end

  @doc "Operation expects a function"
  def not_a_function(operation, actual, opts \\ []) do
    Error.new("E009", "expected a function",
      Keyword.merge(opts, [
        expected: {:fn, [:any], :any},
        actual: actual,
        note: "`#{operation}` requires a function argument"
      ])
    )
  end

  @doc "map/filter function has wrong arity"
  def mapper_arity(operation, expected, actual, opts \\ []) do
    Error.new("E010", "#{operation} function has wrong arity",
      Keyword.merge(opts, [
        note: "`#{operation}` function must take exactly #{expected} argument(s), got #{actual}"
      ])
    )
  end

  @doc "filter predicate must return bool"
  def predicate_not_bool(actual, opts \\ []) do
    Error.new("E011", "predicate must return Bool",
      Keyword.merge(opts, [
        expected: :bool,
        actual: actual,
        hint: "filter predicates must return true or false"
      ])
    )
  end

  # ============================================================================
  # Name Resolution Errors (E100-E199)
  # ============================================================================

  @doc "Variable not defined in scope"
  def undefined_variable(name, opts \\ []) do
    Error.new("E100", "undefined variable",
      Keyword.merge(opts, [
        note: "`#{name}` is not defined in this scope"
      ])
    )
  end

  @doc "Function not found"
  def unknown_function(name, opts \\ []) do
    hint = case suggest_function(name) do
      nil -> nil
      suggestion -> "did you mean `#{suggestion}`?"
    end
    Error.new("E101", "unknown function",
      Keyword.merge(opts, [
        note: "`#{name}` is not defined",
        hint: hint
      ])
    )
  end

  @doc "Type not found"
  def unknown_type(name, opts \\ []) do
    Error.new("E102", "unknown type",
      Keyword.merge(opts, [
        note: "type `#{name}` is not defined"
      ])
    )
  end

  @doc "Process not defined"
  def unknown_process(name, opts \\ []) do
    Error.new("E103", "unknown process",
      Keyword.merge(opts, [
        note: "process `#{name}` is not defined in this module"
      ])
    )
  end

  # ============================================================================
  # Syntax Errors (E200-E299)
  # ============================================================================

  @doc "Invalid defn syntax"
  def invalid_defn_syntax(opts \\ []) do
    Error.new("E200", "invalid function definition",
      Keyword.merge(opts, [
        hint: "expected (defn name [params] body) or (defn name [params] :type body)"
      ])
    )
  end

  @doc "Parse error"
  def parse_error(message, opts \\ []) do
    Error.new("E201", message, opts)
  end

  # ============================================================================
  # Process/Concurrency Errors (E300-E399)
  # ============================================================================

  @doc "Process doesn't accept this message type"
  def invalid_message(process_name, message, accepted, opts \\ []) do
    accepted_str = accepted |> Enum.map(&":#{&1}") |> Enum.join(", ")
    Error.new("E300", "invalid message type",
      Keyword.merge(opts, [
        note: "process `#{process_name}` does not accept `:#{message}`",
        hint: "accepted messages: #{accepted_str}"
      ])
    )
  end

  @doc "Can only send to PIDs"
  def send_to_non_pid(actual, opts \\ []) do
    Error.new("E301", "cannot send to non-pid",
      Keyword.merge(opts, [
        actual: actual,
        note: "the `!` operator requires a PID as the first argument"
      ])
    )
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  # Simple typo correction for common functions
  defp suggest_function(name) when is_atom(name) do
    name_str = Atom.to_string(name)
    common = ~w(map filter fold head tail cons empty? length if let match defn deftype)

    # Find best match above 0.75 threshold (Jaro-Winkler similarity)
    Enum.find(common, fn func ->
      String.jaro_distance(name_str, func) > 0.75
    end)
  end
  defp suggest_function(_), do: nil
end
