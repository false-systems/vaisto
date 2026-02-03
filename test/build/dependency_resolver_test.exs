defmodule Vaisto.Build.DependencyResolverTest do
  use ExUnit.Case, async: true

  alias Vaisto.Build.DependencyResolver

  describe "topological_sort/1" do
    test "sorts empty graph" do
      assert {:ok, []} = DependencyResolver.topological_sort(%{})
    end

    test "sorts single module with no deps" do
      graph = %{
        :"Elixir.Foo" => %{file: "src/Foo.va", imports: []}
      }

      assert {:ok, [%{module: :"Elixir.Foo", file: "src/Foo.va", imports: []}]} =
               DependencyResolver.topological_sort(graph)
    end

    test "sorts linear dependency chain" do
      graph = %{
        :"Elixir.A" => %{file: "src/A.va", imports: []},
        :"Elixir.B" => %{file: "src/B.va", imports: [{:"Elixir.A", nil}]},
        :"Elixir.C" => %{file: "src/C.va", imports: [{:"Elixir.B", nil}]}
      }

      assert {:ok, order} = DependencyResolver.topological_sort(graph)
      modules = Enum.map(order, & &1.module)

      # A must come before B, B must come before C
      assert Enum.find_index(modules, &(&1 == :"Elixir.A")) <
               Enum.find_index(modules, &(&1 == :"Elixir.B"))

      assert Enum.find_index(modules, &(&1 == :"Elixir.B")) <
               Enum.find_index(modules, &(&1 == :"Elixir.C"))
    end

    test "sorts diamond dependency" do
      graph = %{
        :"Elixir.A" => %{file: "src/A.va", imports: []},
        :"Elixir.B" => %{file: "src/B.va", imports: [{:"Elixir.A", nil}]},
        :"Elixir.C" => %{file: "src/C.va", imports: [{:"Elixir.A", nil}]},
        :"Elixir.D" => %{file: "src/D.va", imports: [{:"Elixir.B", nil}, {:"Elixir.C", nil}]}
      }

      assert {:ok, order} = DependencyResolver.topological_sort(graph)
      modules = Enum.map(order, & &1.module)

      # A must come before B, C, D
      # B and C must come before D
      assert Enum.find_index(modules, &(&1 == :"Elixir.A")) <
               Enum.find_index(modules, &(&1 == :"Elixir.B"))

      assert Enum.find_index(modules, &(&1 == :"Elixir.A")) <
               Enum.find_index(modules, &(&1 == :"Elixir.C"))

      assert Enum.find_index(modules, &(&1 == :"Elixir.B")) <
               Enum.find_index(modules, &(&1 == :"Elixir.D"))

      assert Enum.find_index(modules, &(&1 == :"Elixir.C")) <
               Enum.find_index(modules, &(&1 == :"Elixir.D"))
    end

    test "ignores external dependencies" do
      graph = %{
        :"Elixir.Foo" => %{
          file: "src/Foo.va",
          imports: [{:"Elixir.External", nil}, {:"Elixir.Bar", nil}]
        },
        :"Elixir.Bar" => %{file: "src/Bar.va", imports: []}
      }

      assert {:ok, order} = DependencyResolver.topological_sort(graph)
      modules = Enum.map(order, & &1.module)

      # Bar must come before Foo (External is ignored)
      assert Enum.find_index(modules, &(&1 == :"Elixir.Bar")) <
               Enum.find_index(modules, &(&1 == :"Elixir.Foo"))
    end

    test "detects circular dependency" do
      graph = %{
        :"Elixir.A" => %{file: "src/A.va", imports: [{:"Elixir.B", nil}]},
        :"Elixir.B" => %{file: "src/B.va", imports: [{:"Elixir.A", nil}]}
      }

      assert {:error, :circular_dependency} = DependencyResolver.topological_sort(graph)
    end

    test "detects larger circular dependency" do
      graph = %{
        :"Elixir.A" => %{file: "src/A.va", imports: [{:"Elixir.C", nil}]},
        :"Elixir.B" => %{file: "src/B.va", imports: [{:"Elixir.A", nil}]},
        :"Elixir.C" => %{file: "src/C.va", imports: [{:"Elixir.B", nil}]}
      }

      assert {:error, :circular_dependency} = DependencyResolver.topological_sort(graph)
    end
  end

  describe "dependencies/2" do
    test "returns empty list for module with no deps" do
      graph = %{:"Elixir.Foo" => %{file: "src/Foo.va", imports: []}}
      assert [] = DependencyResolver.dependencies(graph, :"Elixir.Foo")
    end

    test "returns internal dependencies only" do
      graph = %{
        :"Elixir.Foo" => %{
          file: "src/Foo.va",
          imports: [{:"Elixir.Bar", nil}, {:"Elixir.External", nil}]
        },
        :"Elixir.Bar" => %{file: "src/Bar.va", imports: []}
      }

      deps = DependencyResolver.dependencies(graph, :"Elixir.Foo")
      assert :"Elixir.Bar" in deps
      refute :"Elixir.External" in deps
    end

    test "returns empty for unknown module" do
      graph = %{:"Elixir.Foo" => %{file: "src/Foo.va", imports: []}}
      assert [] = DependencyResolver.dependencies(graph, :"Elixir.Unknown")
    end
  end

  describe "dependents/2" do
    test "returns modules that depend on given module" do
      graph = %{
        :"Elixir.A" => %{file: "src/A.va", imports: []},
        :"Elixir.B" => %{file: "src/B.va", imports: [{:"Elixir.A", nil}]},
        :"Elixir.C" => %{file: "src/C.va", imports: [{:"Elixir.A", nil}]}
      }

      dependents = DependencyResolver.dependents(graph, :"Elixir.A")
      assert :"Elixir.B" in dependents
      assert :"Elixir.C" in dependents
      assert length(dependents) == 2
    end

    test "returns empty for leaf module" do
      graph = %{
        :"Elixir.A" => %{file: "src/A.va", imports: []},
        :"Elixir.B" => %{file: "src/B.va", imports: [{:"Elixir.A", nil}]}
      }

      assert [] = DependencyResolver.dependents(graph, :"Elixir.B")
    end
  end
end
