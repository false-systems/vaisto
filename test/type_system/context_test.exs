defmodule Vaisto.TypeSystem.ContextTest do
  use ExUnit.Case
  alias Vaisto.TypeSystem.Context
  alias Vaisto.TypeSystem.Core

  describe "new/1" do
    test "creates context with default empty env" do
      ctx = Context.new()
      assert ctx.counter == 0
      assert ctx.subst == %{}
      assert ctx.env == %{}
    end

    test "accepts initial environment" do
      env = %{:+ => {:fn, [:int, :int], :int}}
      ctx = Context.new(env)
      assert ctx.env == env
    end
  end

  describe "fresh_var/1" do
    test "generates incrementing type variables" do
      ctx = Context.new()

      {t0, ctx} = Context.fresh_var(ctx)
      {t1, ctx} = Context.fresh_var(ctx)
      {t2, _ctx} = Context.fresh_var(ctx)

      assert t0 == {:tvar, 0}
      assert t1 == {:tvar, 1}
      assert t2 == {:tvar, 2}
    end
  end

  describe "fresh_vars/2" do
    test "generates multiple fresh variables" do
      ctx = Context.new()
      {vars, ctx} = Context.fresh_vars(ctx, 3)

      assert vars == [{:tvar, 0}, {:tvar, 1}, {:tvar, 2}]
      assert ctx.counter == 3
    end

    test "returns empty list for zero" do
      ctx = Context.new()
      {vars, ctx} = Context.fresh_vars(ctx, 0)

      assert vars == []
      assert ctx.counter == 0
    end
  end

  describe "lookup/2 and extend/3" do
    test "lookup returns :error for missing var" do
      ctx = Context.new()
      assert Context.lookup(ctx, :x) == :error
    end

    test "extend adds binding that can be looked up" do
      ctx = Context.new()
      ctx = Context.extend(ctx, :x, :int)

      assert Context.lookup(ctx, :x) == {:ok, :int}
    end

    test "extend shadows previous bindings" do
      ctx = Context.new()
      ctx = Context.extend(ctx, :x, :int)
      ctx = Context.extend(ctx, :x, :bool)

      assert Context.lookup(ctx, :x) == {:ok, :bool}
    end
  end

  describe "extend_many/2" do
    test "extends with multiple bindings" do
      ctx = Context.new()
      ctx = Context.extend_many(ctx, [{:x, :int}, {:y, :bool}])

      assert Context.lookup(ctx, :x) == {:ok, :int}
      assert Context.lookup(ctx, :y) == {:ok, :bool}
    end
  end

  describe "unify_types/3" do
    test "updates substitution on success" do
      ctx = Context.new()
      {:ok, ctx} = Context.unify_types(ctx, {:tvar, 0}, :int)

      assert Context.apply(ctx, {:tvar, 0}) == :int
    end

    test "returns error on failure" do
      ctx = Context.new()
      assert {:error, _} = Context.unify_types(ctx, :int, :bool)
    end
  end

  describe "instantiate/2" do
    test "replaces quantified variables with fresh ones" do
      ctx = Context.new()
      # forall a. a -> a (identity function scheme)
      scheme = {:forall, [0], {:fn, [{:tvar, 0}], {:tvar, 0}}}

      {type, ctx} = Context.instantiate(ctx, scheme)

      # Should get fresh variable (starts at 0 in fresh context)
      assert type == {:fn, [{:tvar, 0}], {:tvar, 0}}
      assert ctx.counter == 1
    end

    test "handles multiple quantified variables" do
      ctx = Context.new()
      # forall a b. a -> b -> a (const function)
      scheme = {:forall, [0, 1], {:fn, [{:tvar, 0}, {:tvar, 1}], {:tvar, 0}}}

      {type, ctx} = Context.instantiate(ctx, scheme)

      # Fresh vars 0, 1 replace the quantified vars
      assert type == {:fn, [{:tvar, 0}, {:tvar, 1}], {:tvar, 0}}
      assert ctx.counter == 2
    end

    test "returns non-scheme types unchanged" do
      ctx = Context.new()
      {type, ctx} = Context.instantiate(ctx, :int)

      assert type == :int
      assert ctx.counter == 0
    end
  end

  describe "generalize/2" do
    test "generalizes free variables not in env" do
      ctx = Context.new()
      # Type a -> a with no env constraints
      fn_type = {:fn, [{:tvar, 0}], {:tvar, 0}}

      scheme = Context.generalize(ctx, fn_type)

      assert {:forall, [0], {:fn, [{:tvar, 0}], {:tvar, 0}}} = scheme
    end

    test "does not generalize variables in env" do
      ctx = Context.new()
      # x has type t0, so t0 is in env
      ctx = Context.extend(ctx, :x, {:tvar, 0})

      # Type t0 -> t0
      fn_type = {:fn, [{:tvar, 0}], {:tvar, 0}}

      scheme = Context.generalize(ctx, fn_type)

      # Should NOT be generalized since t0 is in env
      assert scheme == fn_type
    end

    test "returns monotype when no free vars" do
      ctx = Context.new()
      scheme = Context.generalize(ctx, {:fn, [:int], :int})

      # No forall wrapper for concrete types
      assert scheme == {:fn, [:int], :int}
    end

    test "applies current substitution before generalizing" do
      ctx = Context.new()
      {:ok, ctx} = Context.unify_types(ctx, {:tvar, 0}, :int)

      # t1 -> t0 where t0 = int
      fn_type = {:fn, [{:tvar, 1}], {:tvar, 0}}
      scheme = Context.generalize(ctx, fn_type)

      # t0 is resolved to :int, only t1 is generalized
      assert {:forall, [1], {:fn, [{:tvar, 1}], :int}} = scheme
    end
  end
end
