defmodule Vaisto.Backend do
  @moduledoc """
  Behaviour for Vaisto compilation backends.

  A backend transforms typed Vaisto AST into executable BEAM bytecode.
  Two backends are provided:

  - `Vaisto.Backend.Core` - Direct Core Erlang emission (default)
  - `Vaisto.Backend.Elixir` - Emission via Elixir AST

  ## Usage

      # Using the behaviour directly
      {:ok, module, binary} = Vaisto.Backend.Core.compile(typed_ast, MyModule)

      # Using the dispatch helper
      {:ok, module, binary} = Vaisto.Backend.compile(:core, typed_ast, MyModule)

  ## Implementing a Backend

  To implement a new backend:

      defmodule Vaisto.Backend.MyBackend do
        @behaviour Vaisto.Backend

        @impl true
        def compile(typed_ast, module_name, opts \\\\ []) do
          # Transform and compile
          {:ok, module_name, binary}
        end

        @impl true
        def to_intermediate(typed_ast, module_name) do
          # Transform to intermediate representation
          intermediate_ast
        end
      end
  """

  @type typed_ast :: term()
  @type compile_result :: {:ok, atom(), binary()} | {:error, String.t()}
  @type compile_opts :: [load: boolean()]

  @doc """
  Compile typed Vaisto AST to BEAM bytecode.

  ## Options

    * `:load` - Whether to load the module into the VM (default: true)

  ## Returns

    * `{:ok, module_name, binary}` - Successful compilation
    * `{:error, reason}` - Compilation failed
  """
  @callback compile(typed_ast(), atom(), compile_opts()) :: compile_result()

  @doc """
  Transform typed Vaisto AST to the backend's intermediate representation.

  For Core backend, this is Core Erlang AST.
  For Elixir backend, this is Elixir quoted AST.
  """
  @callback to_intermediate(typed_ast(), atom()) :: term()

  # ============================================================================
  # Backend Dispatch
  # ============================================================================

  @doc """
  Compile using the specified backend.

  ## Examples

      Vaisto.Backend.compile(:core, typed_ast, MyModule)
      Vaisto.Backend.compile(:elixir, typed_ast, MyModule)
  """
  @spec compile(atom(), typed_ast(), atom(), compile_opts()) :: compile_result()
  def compile(backend, typed_ast, module_name, opts \\ [])

  def compile(:core, typed_ast, module_name, opts) do
    Vaisto.Backend.Core.compile(typed_ast, module_name, opts)
  end

  def compile(:elixir, typed_ast, module_name, opts) do
    Vaisto.Backend.Elixir.compile(typed_ast, module_name, opts)
  end

  @doc """
  Get the backend module for a given backend atom.
  """
  @spec get_backend(atom()) :: module()
  def get_backend(:core), do: Vaisto.Backend.Core
  def get_backend(:elixir), do: Vaisto.Backend.Elixir

  @doc """
  The default backend to use.
  """
  @spec default :: atom()
  def default, do: :core
end
