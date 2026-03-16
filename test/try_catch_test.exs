defmodule Vaisto.TryCatchTest do
  use ExUnit.Case, async: true

  import Vaisto.TestHelpers

  alias Vaisto.Runner

  # ============================================================================
  # Parser Tests
  # ============================================================================

  describe "parser: try/catch" do
    test "basic try/catch parses correctly" do
      ast = parse!("(try 1 [catch [:error e 2]])")
      assert {:try, 1, [{:error, :e, 2}], nil, _loc} = ast
    end

    test "try/after parses correctly" do
      ast = parse!("(try 1 [after 2])")
      assert {:try, 1, [], 2, _loc} = ast
    end

    test "try/catch/after parses correctly" do
      ast = parse!("(try 1 [catch [:error e 2]] [after 3])")
      assert {:try, 1, [{:error, :e, 2}], 3, _loc} = ast
    end

    test "multiple catch clauses" do
      ast = parse!("(try 1 [catch [:error e 2] [:throw v 3]])")
      assert {:try, 1, [{:error, :e, 2}, {:throw, :v, 3}], nil, _loc} = ast
    end

    test "multi-expression body wraps in :do" do
      ast = parse!("(try (+ 1 2) (+ 3 4) [catch [:error e 0]])")
      assert {:try, {:do, _, _}, [{:error, :e, 0}], nil, _loc} = ast
    end

    test "multi-expression handler body wraps in :do" do
      ast = parse!("(try 1 [catch [:error e (+ 1 2) (+ 3 4)]])")
      assert {:try, 1, [{:error, :e, {:do, _, _}}], nil, _loc} = ast
    end

    test "multi-expression after body wraps in :do" do
      ast = parse!("(try 1 [after (+ 1 2) (+ 3 4)])")
      assert {:try, 1, [], {:do, _, _}, _loc} = ast
    end

    test "all three catch classes are valid" do
      ast = parse!("(try 1 [catch [:error e 2] [:throw v 3] [:exit r 4]])")
      assert {:try, _, [{:error, _, _}, {:throw, _, _}, {:exit, _, _}], nil, _loc} = ast
    end
  end

  describe "parser: try error cases" do
    test "empty try" do
      assert {:error, _, _} = parse!("(try)")
    end

    test "try without catch or after" do
      assert {:error, _, _} = parse!("(try 1)")
    end

    test "empty catch block" do
      assert {:error, _, _} = parse!("(try 1 [catch])")
    end

    test "invalid catch class" do
      assert {:error, _, _} = parse!("(try 1 [catch [:foo e 2]])")
    end

    test "catch clause missing body" do
      assert {:error, _, _} = parse!("(try 1 [catch [:error e]])")
    end

    test "empty after block" do
      assert {:error, _, _} = parse!("(try 1 [after])")
    end
  end

  # ============================================================================
  # TypeChecker Tests
  # ============================================================================

  describe "type checker: try/catch" do
    test "body and handler types unify" do
      assert {:ok, :int} = check_type("(try 1 [catch [:error e 2]])")
    end

    test "body and handler type mismatch" do
      assert {:error, _} = check_type(~s|(try 1 [catch [:error e "oops"]])|)
    end

    test "exception var binds as :any" do
      assert {:ok, :int} = check_type("(try 1 [catch [:error e 42]])")
    end

    test "after type is ignored" do
      assert {:ok, :int} = check_type(~s|(try 1 [catch [:error e 2]] [after "cleanup"])|)
    end

    test "try-only-after: result type = body type" do
      assert {:ok, :int} = check_type(~s|(try 42 [after "cleanup"])|)
    end

    test "multiple catch clauses all unify" do
      assert {:ok, :int} = check_type("(try 1 [catch [:error e 2] [:throw v 3]])")
    end

    test "multiple catch clauses type mismatch" do
      assert {:error, _} = check_type(~s|(try 1 [catch [:error e 2] [:throw v "oops"]])|)
    end
  end

  # ============================================================================
  # End-to-end Tests
  # ============================================================================

  describe "e2e: try/catch (elixir backend)" do
    test "catch error" do
      assert {:ok, :caught} = Runner.run(~s|(try (erlang:error :boom) [catch [:error e :caught]])|)
    end

    test "catch throw" do
      assert {:ok, 42} = Runner.run(~s|(try (erlang:throw 42) [catch [:throw v v]])|)
    end

    test "catch exit" do
      assert {:ok, :exited} = Runner.run(~s|(try (erlang:exit :bye) [catch [:exit r :exited]])|)
    end

    test "no exception: body value passes through" do
      assert {:ok, 42} = Runner.run(~s|(try 42 [catch [:error e 0]])|)
    end

    test "after runs on success" do
      code = "(do (erlang:put :after_ran false) (try 42 [catch [:error e 0]] [after (erlang:put :after_ran true)]) (erlang:get :after_ran))"
      assert {:ok, true} = Runner.run(code)
    end

    test "after runs on exception" do
      code = "(do (erlang:put :after_ran false) (try (erlang:error :boom) [catch [:error e :caught]] [after (erlang:put :after_ran true)]) (erlang:get :after_ran))"
      assert {:ok, true} = Runner.run(code)
    end

    test "after-only: exception propagates" do
      code = "(do (erlang:put :after_ran false) (try (try (erlang:error :boom) [after (erlang:put :after_ran true)]) [catch [:error e (erlang:get :after_ran)]]))"
      assert {:ok, true} = Runner.run(code)
    end

    test "nested try/catch" do
      code = "(try (try (erlang:error :inner) [catch [:error e :inner_caught]]) [catch [:error e :outer_caught]])"
      assert {:ok, :inner_caught} = Runner.run(code)
    end

    test "try in function body" do
      code = "(try (erlang:div 10 0) [catch [:error e 0]])"
      assert {:ok, 0} = Runner.run(code)
    end

    test "catch clause var binding" do
      assert {:ok, 100} = Runner.run(~s|(try (erlang:throw 99) [catch [:throw v (+ v 1)]])|)
    end
  end

  describe "e2e: try/catch (core backend)" do
    test "catch error" do
      assert {:ok, :caught} = Runner.run(~s|(try (erlang:error :boom) [catch [:error e :caught]])|, backend: :core)
    end

    test "catch throw" do
      assert {:ok, 42} = Runner.run(~s|(try (erlang:throw 42) [catch [:throw v v]])|, backend: :core)
    end

    test "no exception passes through" do
      assert {:ok, 42} = Runner.run(~s|(try 42 [catch [:error e 0]])|, backend: :core)
    end

    test "after runs on success (core)" do
      code = "(do (erlang:put :after_ran false) (try 42 [catch [:error e 0]] [after (erlang:put :after_ran true)]) (erlang:get :after_ran))"
      assert {:ok, true} = Runner.run(code, backend: :core)
    end

    test "after runs on exception (core)" do
      code = "(do (erlang:put :after_ran false) (try (erlang:error :boom) [catch [:error e :caught]] [after (erlang:put :after_ran true)]) (erlang:get :after_ran))"
      assert {:ok, true} = Runner.run(code, backend: :core)
    end
  end
end
