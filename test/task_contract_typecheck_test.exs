defmodule Vaisto.TaskContractTypecheckTest do
  use ExUnit.Case

  alias Vaisto.{Parser, TypeChecker}

  test "defprompt and pipeline type-check on the happy path" do
    code = """
    (deftype Question [text :string])
    (deftype Answer [text :string])
    (defprompt summarize :input Question :output Answer)
    (pipeline answer-question
      :input Question
      :output Answer
      (generate :prompt summarize :extract Answer))
    """

    ast = Parser.parse(code)

    assert {:ok, :module,
            {:module,
             [
               {:deftype, :Question, {:product, [{:text, :string}]}, {:record, :Question, [{:text, :string}]}},
               {:deftype, :Answer, {:product, [{:text, :string}]}, {:record, :Answer, [{:text, :string}]}},
               {:defprompt, :summarize,
                {:record, :Question, [{:text, :string}]},
                {:record, :Answer, [{:text, :string}]},
                :unit},
               {:pipeline, :"answer-question",
                {:record, :Question, [{:text, :string}]},
                {:record, :Answer, [{:text, :string}]},
                [
                  {:generate, :summarize, {:record, :Answer, [{:text, :string}]}, {:record, :Answer, [{:text, :string}]}}
                ],
                :unit}
             ]}} = TypeChecker.check(ast)
  end
end
