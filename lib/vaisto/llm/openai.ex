defmodule Vaisto.LLM.OpenAI do
  @moduledoc false

  @behaviour Vaisto.LLM

  alias Vaisto.LLM.OpenAI.Schema

  @endpoint ~c"https://api.openai.com/v1/chat/completions"

  @impl true
  def call(prompt_text, _input_data, output_type, opts) do
    with {:ok, api_key} <- fetch_api_key(),
         {:ok, _} <- ensure_http_client(),
         {:ok, body} <- encode_request(prompt_text, output_type, opts),
         {:ok, response_body} <- post_request(body, api_key),
         {:ok, content} <- extract_content(response_body),
         {:ok, parsed_response} <- decode_content(content) do
      {:ok, atomize_to_output_type(parsed_response, output_type)}
    end
  end

  defp fetch_api_key do
    case System.get_env("OPENAI_API_KEY") do
      key when is_binary(key) and key != "" ->
        {:ok, key}

      _ ->
        {:error, {:missing_api_key, "OPENAI_API_KEY is not set"}}
    end
  end

  defp ensure_http_client do
    with {:ok, _} <- Application.ensure_all_started(:inets),
         {:ok, _} <- Application.ensure_all_started(:ssl) do
      {:ok, :started}
    else
      {:error, reason} ->
        {:error, {:http_client_start_failed, reason}}
    end
  end

  defp encode_request(prompt_text, output_type, opts) do
    body = %{
      "model" => Keyword.get(opts, :model, "gpt-4o-mini"),
      "messages" => [
        %{"role" => "user", "content" => prompt_text}
      ],
      "response_format" => %{
        "type" => "json_schema",
        "json_schema" => %{
          "name" => "response",
          "strict" => true,
          "schema" => Schema.to_json_schema(output_type)
        }
      }
    }

    {:ok, Jason.encode!(body)}
  rescue
    e in Jason.EncodeError ->
      {:error, {:request_encode_failed, Exception.message(e)}}
  end

  defp post_request(body, api_key) do
    headers = [
      {~c"authorization", ~c"Bearer " ++ String.to_charlist(api_key)},
      {~c"content-type", ~c"application/json"}
    ]

    request = {@endpoint, headers, ~c"application/json", body}

    case :httpc.request(:post, request, http_options(), body_format: :binary) do
      {:ok, {{_version, 200, _reason_phrase}, _headers, response_body}} ->
        {:ok, response_body}

      {:ok, {{_version, status, _reason_phrase}, _headers, response_body}} ->
        {:error, {:api_error, status, parse_error_body(response_body)}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  defp extract_content(response_body) do
    case Jason.decode(response_body) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} when is_binary(content) ->
        {:ok, content}

      {:ok, _decoded} ->
        {:error, {:invalid_response_shape, response_body}}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:response_decode_failed, Exception.message(error)}}
    end
  end

  defp decode_content(content) do
    case Jason.decode(content) do
      {:ok, parsed} when is_map(parsed) ->
        {:ok, parsed}

      {:ok, other} ->
        {:error, {:content_not_an_object, other}}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:content_decode_failed, Exception.message(error)}}
    end
  end

  defp atomize_to_output_type(data, {:record, _name, fields}) when is_map(data) do
    Map.new(fields, fn {field_name, field_type} ->
      string_key = Atom.to_string(field_name)
      value = Map.fetch!(data, string_key)
      {field_name, atomize_to_output_type(value, field_type)}
    end)
  end

  defp atomize_to_output_type(data, {:list, elem_type}) when is_list(data) do
    Enum.map(data, &atomize_to_output_type(&1, elem_type))
  end

  defp atomize_to_output_type(data, _type), do: data

  defp parse_error_body(response_body) when is_binary(response_body) do
    case Jason.decode(response_body) do
      {:ok, decoded} -> decoded
      {:error, _reason} -> response_body
    end
  end

  defp http_options do
    [
      ssl: [
        verify: :verify_peer,
        cacerts: apply(:public_key, :cacerts_get, [])
      ]
    ]
  end
end
