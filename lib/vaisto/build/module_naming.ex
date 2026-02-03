defmodule Vaisto.Build.ModuleNaming do
  @moduledoc """
  Module naming strategy for Vaisto projects.

  Responsible for inferring module names from file paths using source root
  configuration. This is a pure value object transformation - no side effects.

  ## Source Roots

  A source root is a `{path_prefix, module_prefix}` tuple that defines how
  file paths map to module names:

      {"src/", ""}      # src/Foo/Bar.va → Foo.Bar
      {"lib/", ""}      # lib/Foo/Bar.va → Foo.Bar
      {"std/", "Std."}  # std/List.va → Std.List

  ## Examples

      iex> ModuleNaming.infer("src/Vaisto/Lexer.va")
      :"Elixir.Vaisto.Lexer"

      iex> ModuleNaming.infer("std/List.va")
      :"Elixir.Std.List"

      iex> ModuleNaming.infer("foo.va")
      :"Elixir.Foo"
  """

  @default_source_roots [
    {"src/", ""},
    {"lib/", ""},
    {"std/", "Std."}
  ]

  @type source_root :: {String.t(), String.t()}

  @doc """
  Infer module name from file path using source root configuration.

  ## Options

    * `:source_roots` - list of `{path_prefix, module_prefix}` tuples
      (default: src/, lib/, std/)

  ## Examples

      iex> ModuleNaming.infer("src/Vaisto/Lexer.va")
      :"Elixir.Vaisto.Lexer"

      iex> ModuleNaming.infer("std/List.va", source_roots: [{"std/", "Std."}])
      :"Elixir.Std.List"
  """
  @spec infer(String.t(), keyword()) :: atom()
  def infer(file_path, opts \\ []) do
    source_roots = Keyword.get(opts, :source_roots, @default_source_roots)
    {prefix, relative} = find_root_and_relative(file_path, source_roots)

    module_name =
      relative
      |> Path.rootname(".va")
      |> String.replace("/", ".")
      |> capitalize_segments()

    full_prefix = normalize_prefix(prefix)

    :"Elixir.#{full_prefix}#{module_name}"
  end

  @doc """
  Validate that a declared namespace matches the inferred module name.

  Returns `{:ok, module_name}` if valid, `{:error, message}` if mismatch.
  """
  @spec validate_namespace(atom() | nil, String.t(), keyword()) ::
          {:ok, atom()} | {:error, String.t()}
  def validate_namespace(nil, file_path, opts) do
    {:ok, infer(file_path, opts)}
  end

  def validate_namespace(declared_ns, file_path, opts) do
    inferred = infer(file_path, opts)

    declared_str = declared_ns |> to_string() |> String.replace_prefix("Elixir.", "")
    inferred_str = inferred |> to_string() |> String.replace_prefix("Elixir.", "")

    if declared_str == inferred_str do
      {:ok, inferred}
    else
      {:error,
       "Module name mismatch in #{file_path}: (ns #{declared_ns}) doesn't match inferred name #{inferred}"}
    end
  end

  @doc """
  Returns the default source roots configuration.
  """
  @spec default_source_roots() :: [source_root()]
  def default_source_roots, do: @default_source_roots

  # Private helpers

  defp find_root_and_relative(path, roots) do
    Enum.find_value(roots, fn {root, prefix} ->
      root_dir = String.trim_trailing(root, "/")

      cond do
        # Relative path starting with root
        String.starts_with?(path, root) ->
          {prefix, Path.relative_to(path, root)}

        # Absolute path containing /root/
        String.contains?(path, "/#{root_dir}/") ->
          [_before, relative_part] = String.split(path, "/#{root_dir}/", parts: 2)
          {prefix, relative_part}

        true ->
          nil
      end
    end) || {"", Path.basename(path)}
  end

  defp capitalize_segments(name) do
    name
    |> String.split(".")
    |> Enum.map(fn
      <<first::utf8, rest::binary>> ->
        String.upcase(<<first::utf8>>) <> rest

      "" ->
        ""
    end)
    |> Enum.join(".")
  end

  defp normalize_prefix(""), do: ""
  defp normalize_prefix(p) when is_binary(p) do
    if String.ends_with?(p, "."), do: p, else: p <> "."
  end
end
