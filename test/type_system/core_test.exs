defmodule Vaisto.TypeSystem.CoreTest do
  use ExUnit.Case
  alias Vaisto.TypeSystem.Core

  describe "tvar/1" do
    test "creates type variable tuple" do
      assert Core.tvar(0) == {:tvar, 0}
      assert Core.tvar(42) == {:tvar, 42}
    end
  end

  describe "apply_subst/2" do
    test "substitutes type variable" do
      subst = %{0 => :int}
      assert Core.apply_subst(subst, {:tvar, 0}) == :int
    end

    test "leaves unbound type variable unchanged" do
      subst = %{0 => :int}
      assert Core.apply_subst(subst, {:tvar, 1}) == {:tvar, 1}
    end

    test "follows substitution chains" do
      # t0 -> t1, t1 -> :int means t0 -> :int
      subst = %{0 => {:tvar, 1}, 1 => :int}
      assert Core.apply_subst(subst, {:tvar, 0}) == :int
    end

    test "applies to function types" do
      subst = %{0 => :int, 1 => :bool}
      fn_type = {:fn, [{:tvar, 0}], {:tvar, 1}}
      assert Core.apply_subst(subst, fn_type) == {:fn, [:int], :bool}
    end

    test "applies to list types" do
      subst = %{0 => :string}
      assert Core.apply_subst(subst, {:list, {:tvar, 0}}) == {:list, :string}
    end

    test "applies to record field types" do
      subst = %{0 => :int}
      record = {:record, :point, [{:x, {:tvar, 0}}, {:y, {:tvar, 0}}]}
      expected = {:record, :point, [{:x, :int}, {:y, :int}]}
      assert Core.apply_subst(subst, record) == expected
    end

    test "leaves primitives unchanged" do
      subst = %{0 => :int}
      assert Core.apply_subst(subst, :int) == :int
      assert Core.apply_subst(subst, :bool) == :bool
      assert Core.apply_subst(subst, {:atom, :foo}) == {:atom, :foo}
    end
  end

  describe "compose_subst/2" do
    test "composes two substitutions" do
      s1 = %{0 => {:tvar, 1}}
      s2 = %{1 => :int}
      composed = Core.compose_subst(s1, s2)

      # After composition, t0 should resolve to :int (through t1)
      assert Core.apply_subst(composed, {:tvar, 0}) == :int
      assert Core.apply_subst(composed, {:tvar, 1}) == :int
    end

    test "later substitutions take precedence for same key" do
      s1 = %{0 => :int}
      s2 = %{0 => :bool}
      composed = Core.compose_subst(s1, s2)

      assert Core.apply_subst(composed, {:tvar, 0}) == :bool
    end
  end

  describe "free_vars/1" do
    test "returns empty set for primitives" do
      assert Core.free_vars(:int) == MapSet.new()
      assert Core.free_vars(:bool) == MapSet.new()
    end

    test "returns variable id for type variable" do
      assert Core.free_vars({:tvar, 0}) == MapSet.new([0])
    end

    test "collects variables from function type" do
      fn_type = {:fn, [{:tvar, 0}, {:tvar, 1}], {:tvar, 2}}
      assert Core.free_vars(fn_type) == MapSet.new([0, 1, 2])
    end

    test "collects variables from list type" do
      assert Core.free_vars({:list, {:tvar, 5}}) == MapSet.new([5])
    end

    test "collects variables from record fields" do
      record = {:record, :pair, [{:a, {:tvar, 0}}, {:b, {:tvar, 1}}]}
      assert Core.free_vars(record) == MapSet.new([0, 1])
    end
  end

  describe "format_type/1" do
    test "formats primitive types" do
      assert Core.format_type(:int) == "Int"
      assert Core.format_type(:float) == "Float"
      assert Core.format_type(:bool) == "Bool"
      assert Core.format_type(:string) == "String"
    end

    test "formats type variables" do
      assert Core.format_type({:tvar, 0}) == "t0"
      assert Core.format_type({:tvar, 42}) == "t42"
    end

    test "formats function types" do
      assert Core.format_type({:fn, [:int, :int], :int}) == "(Int, Int) -> Int"
      assert Core.format_type({:fn, [], :bool}) == "() -> Bool"
    end

    test "formats list types" do
      assert Core.format_type({:list, :int}) == "List(Int)"
      assert Core.format_type({:list, {:tvar, 0}}) == "List(t0)"
    end

    test "formats atoms" do
      assert Core.format_type({:atom, :foo}) == ":foo"
    end
  end
end
