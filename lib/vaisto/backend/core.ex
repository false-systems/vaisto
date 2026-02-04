defmodule Vaisto.Backend.Core do
  @moduledoc """
  Core Erlang backend for Vaisto.

  Compiles typed Vaisto AST directly to BEAM bytecode via Core Erlang.
  This is the "deep" path - more control, tighter output.

  Core Erlang is built using the `:cerl` module which constructs
  the AST nodes that `:compile.forms/2` understands.
  """

  @behaviour Vaisto.Backend

  # Delegate to existing CoreEmitter implementation
  # This maintains backwards compatibility while providing the new interface

  @impl true
  @doc """
  Compile typed AST directly to BEAM bytecode via Core Erlang.

  ## Options

    * `:load` - whether to load the module into the VM (default: true)

  ## Returns

    * `{:ok, module_name, binary}` - Successful compilation
    * `{:error, reason}` - Compilation failed
  """
  def compile(typed_ast, module_name, opts \\ []) do
    Vaisto.CoreEmitter.compile(typed_ast, module_name, opts)
  end

  @impl true
  @doc """
  Transform typed Vaisto AST to Core Erlang AST.

  The resulting AST can be compiled using `:compile.forms/2`.
  """
  def to_intermediate(typed_ast, module_name) do
    Vaisto.CoreEmitter.to_core(typed_ast, module_name)
  end

  # ============================================================================
  # Convenience Functions
  # ============================================================================

  @doc """
  Compile and load the module into the VM.

  Convenience wrapper that always loads the compiled module.
  """
  def compile_and_load(typed_ast, module_name \\ :VaistoModule) do
    Vaisto.CoreEmitter.compile_and_load(typed_ast, module_name)
  end

  @doc """
  Transform typed Vaisto AST to Core Erlang AST.

  Alias for `to_intermediate/2` for API compatibility.
  """
  def to_core(typed_ast, module_name) do
    to_intermediate(typed_ast, module_name)
  end
end
