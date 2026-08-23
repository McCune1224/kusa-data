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

  @doc """
  Paged query with a complexity fallback. start.gg rejects any request that
  would return more than 1000 objects, and the count depends on how much
  nested data (games, selections) actually comes back — so the same perPage
  can pass for one page and fail for another.

  `query_fn` receives the page size and returns a `{document, variables}`
  tuple. On a complexity rejection the request is retried at half the page
  size (down to 10), so dense pages degrade gracefully instead of failing.
  """
  @spec query_paged((pos_integer() -> {String.t(), map()}), pos_integer()) ::
          {:ok, map()} | {:error, term()}
  def query_paged(query_fn, per_page)

  def query_paged(query_fn, per_page) when per_page >= 20 do
    case query(query_fn.(per_page)) do
      {:error, {:graphql, [%{"message" => message}]}} = error ->
        if String.contains?(message, "complexity") do
          query_paged(query_fn, div(per_page, 2))
        else
          error
        end

      other ->
        other
    end
  end

  def query_paged(query_fn, _per_page), do: query(query_fn.(10))

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
