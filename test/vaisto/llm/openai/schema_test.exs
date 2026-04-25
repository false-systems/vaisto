defmodule Vaisto.LLM.OpenAI.SchemaTest do
  use ExUnit.Case, async: true

  alias Vaisto.LLM.OpenAI.Schema

  test ":string becomes a string schema" do
    assert Schema.to_json_schema(:string) == %{"type" => "string"}
  end

  test "{:list, :int} becomes an array of integers" do
    assert Schema.to_json_schema({:list, :int}) == %{
             "type" => "array",
             "items" => %{"type" => "integer"}
           }
  end

  test "record becomes a strict object with all fields required" do
    schema =
      Schema.to_json_schema({:record, :Answer, [{:text, :string}, {:count, :int}, {:ok, :bool}]})

    assert schema == %{
             "type" => "object",
             "properties" => %{
               "text" => %{"type" => "string"},
               "count" => %{"type" => "integer"},
               "ok" => %{"type" => "boolean"}
             },
             "required" => ["text", "count", "ok"],
             "additionalProperties" => false
           }
  end

  test "nested record becomes a nested strict object schema" do
    schema =
      Schema.to_json_schema(
        {:record, :Outer,
         [
           {:title, :string},
           {:meta, {:record, :Meta, [{:published, :bool}, {:score, :float}]}}
         ]}
      )

    assert schema == %{
             "type" => "object",
             "properties" => %{
               "title" => %{"type" => "string"},
               "meta" => %{
                 "type" => "object",
                 "properties" => %{
                   "published" => %{"type" => "boolean"},
                   "score" => %{"type" => "number"}
                 },
                 "required" => ["published", "score"],
                 "additionalProperties" => false
               }
             },
             "required" => ["title", "meta"],
             "additionalProperties" => false
           }
  end

  test "unsupported types raise with a clear message" do
    assert_raise ArgumentError, ~r/OpenAI structured outputs do not support type/, fn ->
      Schema.to_json_schema(:atom)
    end
  end
end
