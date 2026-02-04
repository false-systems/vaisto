defmodule Vaisto.Backend.Elixir do
  @moduledoc """
  Elixir AST backend for Vaisto.

  Compiles typed Vaisto AST to BEAM bytecode via Elixir's compiler.

  Strategy: Vaisto AST → Elixir AST → BEAM

  This leverages Elixir's compiler instead of targeting Core Erlang
  directly. More sustainable, better documented, battle-tested.
  """

  @behaviour Vaisto.Backend

  # Delegate to existing Emitter implementation
  # This maintains backwards compatibility while providing the new interface

  @impl true
  @doc """
  Compile typed AST to BEAM bytecode via Elixir compiler.

  ## Options

    * `:load` - whether to load the module into the VM (default: true)
      Note: The Elixir backend always loads modules during compilation.

  ## Returns

    * `{:ok, module_name, binary}` - Successful compilation
    * `{:error, reason}` - Compilation failed
  """
  def compile(typed_ast, module_name, opts \\ []) do
    # Note: Elixir backend doesn't support :load option (always loads)
    _ = opts
    Vaisto.Emitter.compile(typed_ast, module_name)
  end

  @impl true
  @doc """
  Transform typed Vaisto AST to Elixir quoted AST.

  The resulting AST can be compiled using `Code.compile_quoted/1`.
  """
  def to_intermediate(typed_ast, _module_name) do
    Vaisto.Emitter.to_elixir(typed_ast)
  end

  # ============================================================================
  # Convenience Functions
  # ============================================================================

  @doc """
  Transform typed Vaisto AST to Elixir AST (quoted form).

  Alias for `to_intermediate/2` for API compatibility.

  ## Example

      iex> Backend.Elixir.to_elixir({:lit, :int, 42})
      42

      iex> Backend.Elixir.to_elixir({:call, :+, [{:lit, :int, 1}, {:lit, :int, 2}], :int})
      {:+, [], [1, 2]}
  """
  def to_elixir(typed_ast) do
    Vaisto.Emitter.to_elixir(typed_ast)
  end
end
