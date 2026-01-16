defmodule Vaisto.TypeSystem.Unify do
  @moduledoc """
  Unification algorithm for Hindley-Milner type inference.

  Unification finds a substitution that makes two types equal.
  For example, unifying {:tvar, 0} with :int produces {0 => :int}.
  """

  import Vaisto.TypeSystem.Core

  @doc """
  Attempts to unify two types, returning an updated substitution.

  Returns {:ok, subst} on success, {:error, reason} on failure.
  """
  def unify(t1, t2, subst \\ empty_subst())

  def unify(t1, t2, subst) do
    # Apply current substitutions first to get "real" types
    t1 = apply_subst(subst, t1)
    t2 = apply_subst(subst, t2)

    cond do
      # Same type - nothing to do
      t1 == t2 ->
        {:ok, subst}

      # Type variable on left - bind it
      match?({:tvar, _}, t1) ->
        bind_var(t1, t2, subst)

      # Type variable on right - bind it
      match?({:tvar, _}, t2) ->
        bind_var(t2, t1, subst)

      # List types - unify element types
      match?({:list, _}, t1) and match?({:list, _}, t2) ->
        {:list, elem1} = t1
        {:list, elem2} = t2
        unify(elem1, elem2, subst)

      # Function types - unify args and return
      match?({:fn, _, _}, t1) and match?({:fn, _, _}, t2) ->
        {:fn, args1, ret1} = t1
        {:fn, args2, ret2} = t2

        if length(args1) != length(args2) do
          {:error, "function arity mismatch: #{length(args1)} vs #{length(args2)}"}
        else
          case unify_lists(args1, args2, subst) do
            {:ok, subst} -> unify(ret1, ret2, subst)
            error -> error
          end
        end

      # Record types - unify field types
      match?({:record, _, _}, t1) and match?({:record, _, _}, t2) ->
        {:record, name1, fields1} = t1
        {:record, name2, fields2} = t2

        if name1 != name2 do
          {:error, "cannot unify records #{name1} and #{name2}"}
        else
          unify_fields(fields1, fields2, subst)
        end

      # Tuple types - unify element types
      match?({:tuple, _}, t1) and match?({:tuple, _}, t2) ->
        {:tuple, elems1} = t1
        {:tuple, elems2} = t2

        if length(elems1) != length(elems2) do
          {:error, "tuple size mismatch: #{length(elems1)} vs #{length(elems2)}"}
        else
          unify_lists(elems1, elems2, subst)
        end

      # No match - types are incompatible
      true ->
        {:error, "cannot unify #{format_type(t1)} with #{format_type(t2)}"}
    end
  end

  @doc """
  Binds a type variable to a type, with occurs check.

  The occurs check prevents infinite types like: a = List(a)
  """
  def bind_var({:tvar, id}, type, subst) do
    # Occurs check: ensure we're not creating an infinite type
    if occurs?(id, type) do
      {:error, "infinite type: t#{id} occurs in #{format_type(type)}"}
    else
      {:ok, Map.put(subst, id, type)}
    end
  end

  @doc """
  Checks if a type variable occurs within a type.
  Used to prevent infinite types.
  """
  def occurs?(id, {:tvar, id}), do: true
  def occurs?(_id, {:tvar, _}), do: false
  def occurs?(id, {:list, elem}), do: occurs?(id, elem)
  def occurs?(id, {:fn, args, ret}) do
    Enum.any?(args, &occurs?(id, &1)) or occurs?(id, ret)
  end
  def occurs?(id, {:tuple, elems}) do
    Enum.any?(elems, &occurs?(id, &1))
  end
  def occurs?(id, {:record, _name, fields}) do
    Enum.any?(fields, fn {_k, v} -> occurs?(id, v) end)
  end
  def occurs?(_id, _type), do: false

  @doc """
  Unifies two lists of types pairwise.
  """
  def unify_lists([], [], subst), do: {:ok, subst}
  def unify_lists([t1 | rest1], [t2 | rest2], subst) do
    case unify(t1, t2, subst) do
      {:ok, subst} -> unify_lists(rest1, rest2, subst)
      error -> error
    end
  end

  @doc """
  Unifies record fields by name.
  """
  def unify_fields(fields1, fields2, subst) do
    # Build a map for quick lookup
    map1 = Map.new(fields1)
    map2 = Map.new(fields2)

    # All keys must match
    if Map.keys(map1) |> Enum.sort() != Map.keys(map2) |> Enum.sort() do
      {:error, "record field mismatch"}
    else
      Enum.reduce_while(map1, {:ok, subst}, fn {key, type1}, {:ok, acc_subst} ->
        type2 = Map.fetch!(map2, key)
        case unify(type1, type2, acc_subst) do
          {:ok, new_subst} -> {:cont, {:ok, new_subst}}
          error -> {:halt, error}
        end
      end)
    end
  end
end
