defmodule Vaisto.Build.ModuleNamingTest do
  use ExUnit.Case, async: true

  alias Vaisto.Build.ModuleNaming

  describe "infer/2" do
    test "infers module name from src/ path" do
      assert ModuleNaming.infer("src/Foo.va") == :"Elixir.Foo"
      assert ModuleNaming.infer("src/Foo/Bar.va") == :"Elixir.Foo.Bar"
      assert ModuleNaming.infer("src/Vaisto/Lexer.va") == :"Elixir.Vaisto.Lexer"
    end

    test "infers module name from lib/ path" do
      assert ModuleNaming.infer("lib/Foo.va") == :"Elixir.Foo"
      assert ModuleNaming.infer("lib/Foo/Bar.va") == :"Elixir.Foo.Bar"
    end

    test "infers module name from std/ path with Std. prefix" do
      assert ModuleNaming.infer("std/List.va") == :"Elixir.Std.List"
      assert ModuleNaming.infer("std/Option.va") == :"Elixir.Std.Option"
      assert ModuleNaming.infer("std/Result.va") == :"Elixir.Std.Result"
    end

    test "handles absolute paths" do
      assert ModuleNaming.infer("/home/user/project/src/Foo/Bar.va") == :"Elixir.Foo.Bar"
      assert ModuleNaming.infer("/home/user/project/std/List.va") == :"Elixir.Std.List"
    end

    test "falls back to basename for unmatched paths" do
      assert ModuleNaming.infer("random/path/foo.va") == :"Elixir.Foo"
      assert ModuleNaming.infer("unknown.va") == :"Elixir.Unknown"
    end

    test "capitalizes module segments" do
      assert ModuleNaming.infer("src/foo.va") == :"Elixir.Foo"
      assert ModuleNaming.infer("src/foo/bar.va") == :"Elixir.Foo.Bar"
    end

    test "accepts custom source roots" do
      custom_roots = [{"custom/", "MyApp."}]
      assert ModuleNaming.infer("custom/Foo.va", source_roots: custom_roots) == :"Elixir.MyApp.Foo"
      assert ModuleNaming.infer("custom/Bar/Baz.va", source_roots: custom_roots) == :"Elixir.MyApp.Bar.Baz"
    end

    test "handles deeply nested paths" do
      assert ModuleNaming.infer("src/A/B/C/D.va") == :"Elixir.A.B.C.D"
    end
  end

  describe "validate_namespace/3" do
    test "returns ok when namespace is nil" do
      assert {:ok, :"Elixir.Foo"} = ModuleNaming.validate_namespace(nil, "src/Foo.va", [])
    end

    test "returns ok when namespace matches inferred name" do
      assert {:ok, :"Elixir.Foo"} = ModuleNaming.validate_namespace(:Foo, "src/Foo.va", [])
      assert {:ok, :"Elixir.Foo.Bar"} = ModuleNaming.validate_namespace(:"Foo.Bar", "src/Foo/Bar.va", [])
    end

    test "returns ok with Elixir. prefixed namespace" do
      assert {:ok, :"Elixir.Foo"} = ModuleNaming.validate_namespace(:"Elixir.Foo", "src/Foo.va", [])
    end

    test "returns error when namespace doesn't match" do
      assert {:error, message} = ModuleNaming.validate_namespace(:Wrong, "src/Foo.va", [])
      assert message =~ "Module name mismatch"
      assert message =~ "Wrong"
      assert message =~ "Foo"
    end
  end

  describe "default_source_roots/0" do
    test "returns default source roots" do
      roots = ModuleNaming.default_source_roots()
      assert {"src/", ""} in roots
      assert {"lib/", ""} in roots
      assert {"std/", "Std."} in roots
    end
  end
end
