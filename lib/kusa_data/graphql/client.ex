defmodule KusaData.GraphQL.Client do
  @moduledoc """
  start.gg GraphQL client: bearer auth, rate-limited, with retry on 429.

  Returns `{:ok, data}` or `{:error, reason}` and never raises. GraphQL-level
  errors (validation, auth, unknown fields) are returned as
  `{:error, {:graphql, errors}}` and are not retried — only HTTP 429 is.
  """

  @endpoint "https://api.start.gg/gql/alpha"
  @max_retries 3
  @base_backoff_ms 1_000

  alias KusaData.GraphQL.RateLimiter

  @spec query(String.t() | {String.t(), map()}, map()) :: {:ok, map()} | {:error, term()}
  def query({document, variables}), do: query(document, variables)

  def query(document, variables \\ %{}) when is_binary(document) do
    RateLimiter.wait()
    request(document, variables, 0)
  end

  defp request(document, variables, retries) do
    body = %{"query" => document, "variables" => variables}

    case transport().post(@endpoint, body, headers()) do
      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        {:error, {:graphql, errors}}

      {:ok, %{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %{status: 429}} when retries < @max_retries ->
        Process.sleep(@base_backoff_ms * Integer.pow(2, retries))
        request(document, variables, retries + 1)

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp headers do
    [{"authorization", "Bearer #{token()}"}, {"content-type", "application/json"}]
  end

  defp token do
    Application.get_env(:kusa_data, __MODULE__, [])
    |> Keyword.get(:token)
    |> case do
      nil -> System.get_env("ACCESS_TOKEN", "")
      token -> token
    end
  end

  defp transport do
    Application.get_env(:kusa_data, __MODULE__, [])
    |> Keyword.get(:transport, KusaData.GraphQL.ReqTransport)
  end
end
