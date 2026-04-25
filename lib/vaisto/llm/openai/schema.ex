defmodule Vaisto.LLM.OpenAI.Schema do
  @moduledoc false

  @spec to_json_schema(term()) :: map()
  def to_json_schema(:string), do: %{"type" => "string"}
  def to_json_schema(:int), do: %{"type" => "integer"}
  def to_json_schema(:bool), do: %{"type" => "boolean"}
  def to_json_schema(:float), do: %{"type" => "number"}

  def to_json_schema({:list, elem_type}) do
    %{
      "type" => "array",
      "items" => to_json_schema(elem_type)
    }
  end

  def to_json_schema({:record, _name, fields}) when is_list(fields) do
    properties =
      Map.new(fields, fn {field_name, field_type} ->
        {Atom.to_string(field_name), to_json_schema(field_type)}
      end)

    %{
      "type" => "object",
      "properties" => properties,
      "required" => Enum.map(fields, fn {field_name, _field_type} -> Atom.to_string(field_name) end),
      "additionalProperties" => false
    }
  end

  def to_json_schema(other) do
    raise ArgumentError, "OpenAI structured outputs do not support type: #{inspect(other)}"
  end
end
