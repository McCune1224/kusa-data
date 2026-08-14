defmodule KusaData.GraphQL.Client do
  @moduledoc """
  start.gg GraphQL client: bearer auth, sliding-window rate limiting, exponential
  backoff on 429, and a receive timeout so a hung upstream can't block a request
  forever. Returns `{:ok, data}` or `{:error, reason}` — never raises.

  Config (`:kusa_data, __MODULE__`): `:endpoint`, `:token`, `:retries` (default 4),
  `:backoff_ms` (default 1500).
  """

  @default_endpoint "https://api.start.gg/gql/alpha"
  @default_retries 4
  @default_backoff_ms 1500

  alias KusaData.GraphQL.RateLimiter

  def request(document, variables \\ %{}) do
    RateLimiter.wait()
    do_request(document, variables, 0)
  end

  defp do_request(document, variables, retries) do
    case Req.post(endpoint(), json: %{query: document, variables: variables}, headers: headers()) do
      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        # validation/complexity errors are permanent — do not retry
        {:error, {:graphql, errors}}

      {:ok, %{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %{status: 429}} ->
        if retries < max_retries() do
          Process.sleep(backoff(retries))
          do_request(document, variables, retries + 1)
        else
          {:error, :rate_limited}
        end

      {:ok, %{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp headers do
    [{"authorization", "Bearer #{token()}"}, {"content-type", "application/json"}]
  end

  defp endpoint do
    Application.get_env(:kusa_data, __MODULE__, []) |> Keyword.get(:endpoint, @default_endpoint)
  end

  defp token do
    Application.get_env(:kusa_data, __MODULE__, [])
    |> Keyword.get(:token, System.get_env("ACCESS_TOKEN", ""))
  end

  defp max_retries,
    do: Application.get_env(:kusa_data, __MODULE__, []) |> Keyword.get(:retries, @default_retries)

  defp backoff(n) do
    base =
      Application.get_env(:kusa_data, __MODULE__, [])
      |> Keyword.get(:backoff_ms, @default_backoff_ms)

    base * Integer.pow(2, n)
  end
end
