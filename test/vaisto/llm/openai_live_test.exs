defmodule Vaisto.LLM.OpenAILiveTest do
  use ExUnit.Case, async: false

  @tag :live
  @tag skip: (System.get_env("OPENAI_API_KEY") in [nil, ""] && "OPENAI_API_KEY is not set")
  test "call/4 returns a parsed map from the OpenAI API" do
    output_type = {:record, :Answer, [{:text, :string}]}

    assert {:ok, %{text: text}} =
             Vaisto.LLM.OpenAI.call(
               "Return JSON with one field text set to hello.",
               %{},
               output_type,
               model: "gpt-4o-mini"
             )

    assert is_binary(text)
  end
end
