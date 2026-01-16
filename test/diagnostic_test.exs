defmodule Vaisto.DiagnosticTest do
  use ExUnit.Case
  alias Vaisto.Diagnostic
  alias Vaisto.Parser.Loc

  describe "new/3" do
    test "creates diagnostic from location" do
      loc = %Loc{line: 3, col: 5, file: "test.va"}

      diag = Diagnostic.new(loc, "something went wrong")

      assert diag.message == "something went wrong"
      assert diag.line == 3
      assert diag.col == 5
      assert diag.file == "test.va"
      assert diag.severity == :error
    end

    test "accepts optional span_length and hint" do
      loc = %Loc{line: 1, col: 1, file: nil}

      diag = Diagnostic.new(loc, "msg", span_length: 5, hint: "try this")

      assert diag.span_length == 5
      assert diag.hint == "try this"
    end
  end

  describe "type_mismatch/4" do
    test "creates type mismatch diagnostic with formatted types" do
      loc = %Loc{line: 2, col: 3, file: "foo.va"}

      diag = Diagnostic.type_mismatch(loc, :int, {:atom, :bad})

      assert diag.message =~ "type mismatch"
      assert diag.message =~ "expected Int"
      assert diag.message =~ "found Atom(:bad)"
    end

    test "formats complex types" do
      loc = %Loc{line: 1, col: 1, file: nil}

      diag = Diagnostic.type_mismatch(loc, {:list, :int}, {:fn, [:int], :int})

      assert diag.message =~ "List(Int)"
      assert diag.message =~ "(Int) -> Int"
    end
  end

  describe "unknown_function/3" do
    test "creates unknown function diagnostic with hint" do
      loc = %Loc{line: 1, col: 2, file: "test.va"}

      diag = Diagnostic.unknown_function(loc, :foo)

      assert diag.message =~ "unknown function `foo`"
      assert diag.hint =~ "did you mean"
      assert diag.span_length == 3  # "foo"
    end
  end

  describe "arity_mismatch/4" do
    test "creates arity mismatch diagnostic" do
      loc = %Loc{line: 1, col: 2, file: nil}

      diag = Diagnostic.arity_mismatch(loc, :add, 2, 1)

      assert diag.message =~ "function `add` expects 2 argument(s), found 1"
    end
  end

  describe "undefined_variable/2" do
    test "creates undefined variable diagnostic" do
      loc = %Loc{line: 5, col: 3, file: "test.va"}

      diag = Diagnostic.undefined_variable(loc, :my_var)

      assert diag.message =~ "undefined variable `my_var`"
      assert diag.span_length == 6  # "my_var"
    end
  end

  describe "invalid_message/4" do
    test "creates invalid message diagnostic with valid options" do
      loc = %Loc{line: 10, col: 5, file: "test.va"}

      diag = Diagnostic.invalid_message(loc, :counter, :invalid, [:increment, :decrement])

      assert diag.message =~ "process `counter` does not accept message `:invalid`"
      assert diag.hint =~ ":increment, :decrement"
    end
  end

  describe "format/2" do
    test "formats diagnostic with source in Rust style" do
      loc = %Loc{line: 1, col: 6, file: "test.va"}
      diag = Diagnostic.new(loc, "test error", span_length: 4)
      source = "(+ 1 :bad)"

      result = Diagnostic.format(diag, source)

      assert result =~ "error"
      assert result =~ "test error"
      assert result =~ "test.va:1:6"
      assert result =~ "(+ 1 :bad)"
      assert result =~ "^^^^"
    end
  end
end
