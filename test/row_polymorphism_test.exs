defmodule Vaisto.RowPolymorphismTest do
  use ExUnit.Case
  alias Vaisto.Parser
  alias Vaisto.TypeChecker

  describe "field access parsing" do
    test "parses simple field access" do
      code = "(. person :name)"
      ast = Parser.parse(code)
      assert {:field_access, :person, :name, _loc} = ast
    end

    test "parses field access on expression" do
      code = "(. (get-user) :email)"
      ast = Parser.parse(code)
      assert {:field_access, {:call, :"get-user", [], _}, :email, _loc} = ast
    end
  end

  describe "field access type checking" do
    test "field access on record returns field type" do
      code = """
      (deftype Person [name :string age :int])
      (defn get-name [p] (. p :name))
      """
      ast = Parser.parse(code)
      {:ok, _type, _typed_ast} = TypeChecker.check(ast)
    end

    test "field access on unknown type returns any" do
      code = "(defn get-x [r] (. r :x))"
      ast = Parser.parse(code)
      # Should type check - we just don't know the exact type
      {:ok, _type, _typed_ast} = TypeChecker.check(ast)
    end
  end

  describe "row type representation" do
    test "row type unifies with record" do
      alias Vaisto.TypeSystem.Unify

      # A row that requires :name field
      row = {:row, [{:name, :string}], {:rvar, 0}}
      # A record with :name and :age fields
      record = {:record, :Person, [{:name, :string}, {:age, :int}]}

      # Should unify - row captures extra :age field
      assert {:ok, _subst, _} = Unify.unify_row_with_record(
        [{:name, :string}],
        {:rvar, 0},
        [{:name, :string}, {:age, :int}],
        %{}
      )
    end

    test "closed row rejects extra fields" do
      alias Vaisto.TypeSystem.Unify

      # Should fail - closed row doesn't accept extra fields
      result = Unify.unify_row_with_record(
        [{:name, :string}],
        :closed,
        [{:name, :string}, {:age, :int}],
        %{}
      )

      assert {:error, _} = result
    end

    test "row type unification preserves common fields" do
      alias Vaisto.TypeSystem.Unify

      row1 = {:row, [{:x, :int}], {:rvar, 0}}
      row2 = {:row, [{:x, :int}, {:y, :int}], :closed}

      assert {:ok, _subst, _} = Unify.unify_rows(row1, row2, %{}, 0)
    end
  end

  describe "row type formatting" do
    test "formats open row type" do
      alias Vaisto.TypeSystem.Core

      row = {:row, [{:name, :string}, {:age, :int}], {:rvar, 0}}
      formatted = Core.format_type(row)

      assert formatted =~ "name:"
      assert formatted =~ "age:"
      # Row variables now use ..a, ..b style
      assert formatted =~ "..a"
    end

    test "formats closed row type" do
      alias Vaisto.TypeSystem.Core

      row = {:row, [{:name, :string}], :closed}
      formatted = Core.format_type(row)

      assert formatted == "{name: String}"
    end
  end
end
