defmodule Vaisto.TaskContractParserTest do
  use ExUnit.Case

  alias Vaisto.Parser

  describe "defprompt parsing" do
    test "parses a top-level defprompt" do
      ast = Parser.parse("(defprompt summarize :input Document :output Summary)")

      assert {:defprompt, :summarize, :Document, :Summary, %Vaisto.Parser.Loc{line: 1, col: 1}} = ast
    end

    test "rejects malformed defprompt syntax" do
      ast = Parser.parse("(defprompt summarize :input Document)")

      assert {:error, %Vaisto.Error{message: "defprompt requires syntax: (defprompt NAME :input TYPE :output TYPE)"}, _loc} = ast
    end
  end

  describe "pipeline parsing" do
    test "parses a top-level pipeline with generate ops" do
      code = """
      (pipeline answer
        :input Question
        :output Answer
        (generate :prompt summarize :extract Answer))
      """

      ast = Parser.parse(code)

      assert {:pipeline, :answer, :Question, :Answer, [op], %Vaisto.Parser.Loc{line: 1, col: 1}} = ast
      assert {:generate, :summarize, :Answer, %Vaisto.Parser.Loc{line: 4, col: 3}} = op
    end

    test "rejects pipeline without operators" do
      ast = Parser.parse("(pipeline answer :input Question :output Answer)")

      assert {:error, %Vaisto.Error{message: "pipeline requires at least one operator"}, _loc} = ast
    end
  end

  describe "generate parsing" do
    test "parses a generate operator" do
      ast = Parser.parse("(generate :prompt summarize :extract (List Summary))")

      assert {:generate, :summarize, {:call, :List, [:Summary], %Vaisto.Parser.Loc{}}, %Vaisto.Parser.Loc{line: 1, col: 1}} = ast
    end

    test "rejects malformed generate syntax" do
      ast = Parser.parse("(generate :extract Summary)")

      assert {:error, %Vaisto.Error{message: "generate requires syntax: (generate :prompt PROMPT_NAME :extract TYPE)"}, _loc} = ast
    end
  end
end
