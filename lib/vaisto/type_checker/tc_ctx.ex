defmodule Vaisto.TypeChecker.TcCtx do
  @moduledoc """
  Type-checking context that threads a substitution and row counter
  through the TypeChecker.

  The row_counter tracks fresh row variable IDs to prevent collisions
  when multiple row-polymorphic unifications occur in the same expression.
  """

  alias Vaisto.TypeSystem.Core
  alias Vaisto.TypeSystem.Unify

  defstruct [:env, :subst, row_counter: 0]

  @doc "Create a new context from a type environment."
  def new(env), do: %__MODULE__{env: env, subst: Core.empty_subst(), row_counter: 0}

  @doc "Unify two types within this context, updating the substitution and row counter."
  def unify(%__MODULE__{subst: subst, row_counter: rc} = ctx, t1, t2) do
    case Unify.unify(t1, t2, subst, rc) do
      {:ok, new_subst, new_rc} -> {:ok, %{ctx | subst: new_subst, row_counter: new_rc}}
      {:error, _} = err -> err
    end
  end

  @doc "Apply the current substitution to a type."
  def apply_subst(%__MODULE__{subst: subst}, type) do
    Core.apply_subst(subst, type)
  end
end
