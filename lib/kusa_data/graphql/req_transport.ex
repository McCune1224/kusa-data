defmodule KusaData.GraphQL.ReqTransport do
  @moduledoc """
  Production HTTP transport backed by `Req`.

  JSON bodies are decoded by Req automatically; non-JSON payloads are left
  as raw strings.
  """

  @behaviour KusaData.GraphQL.Transport

  @timeout 30_000

  @impl true
  def post(url, body, headers) do
    case Req.post(url, json: body, headers: headers, receive_timeout: @timeout) do
      {:ok, %{status: status, body: response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def get(url, headers) do
    case Req.get(url, headers: headers, receive_timeout: @timeout) do
      {:ok, %{status: status, body: response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
