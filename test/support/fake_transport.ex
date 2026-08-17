defmodule KusaData.Test.FakeTransport do
  @moduledoc """
  In-memory stand-in for `KusaData.GraphQL.ReqTransport`.

  GraphQL POST bodies are routed by operation name (`query Foo(...)`), so
  each test seeds fixtures like:

      FakeTransport.put(:query, "NearbyTournaments", %{"data" => ...})

  A fixture can also be:

    * a function `(attempt :: pos_integer) -> response` for retry tests
    * a raw `%{status: ...}` map to simulate HTTP-level responses

  Geocoding GETs are routed by URL substring:

      FakeTransport.put(:url, "zippopotam.us", %{"places" => [...]})

  Missing fixtures produce an explicit `{:error, :missing_fixture}` so tests
  fail loudly instead of silently returning empty payloads.
  """

  use Agent

  @name __MODULE__

  @behaviour KusaData.GraphQL.Transport

  def start_link(_opts) do
    Agent.start_link(fn -> %{queries: %{}, urls: [], attempts: %{}} end, name: @name)
  end

  def put(:query, operation, fixture) do
    Agent.update(@name, fn state ->
      %{state | queries: Map.put(state.queries, operation, fixture)}
    end)

    :ok
  end

  def put(:url, substring, fixture) do
    Agent.update(@name, fn state ->
      %{state | urls: [{substring, fixture} | state.urls]}
    end)

    :ok
  end

  @impl true
  def post(_url, body, _headers) do
    case operation_name(body) do
      nil ->
        {:error, :unparseable_document}

      operation ->
        case Agent.get(@name, &Map.get(&1.queries, operation)) do
          nil ->
            {:error, {:missing_fixture, operation}}

          fixture ->
            attempt =
              Agent.get_and_update(@name, fn state ->
                {Map.get(state.attempts, operation, 0) + 1,
                 %{
                   state
                   | attempts:
                       Map.put(
                         state.attempts,
                         operation,
                         Map.get(state.attempts, operation, 0) + 1
                       )
                 }}
              end)

            respond(if(is_function(fixture, 1), do: fixture.(attempt), else: fixture))
        end
    end
  end

  @impl true
  def get(url, _headers) do
    case Agent.get(@name, &find_url(&1.urls, url)) do
      nil -> {:error, {:missing_fixture, url}}
      fixture -> respond(fixture)
    end
  end

  defp respond(%{error: reason}) do
    {:error, reason}
  end

  defp respond(%{status: _status} = response) do
    {:ok, Map.put_new(response, :body, nil)}
  end

  defp respond(body) do
    {:ok, %{status: 200, body: body}}
  end

  defp find_url(urls, url) do
    Enum.find_value(urls, fn {substring, fixture} ->
      if String.contains?(url, substring), do: fixture
    end)
  end

  defp operation_name(%{"query" => document}) when is_binary(document) do
    case Regex.run(~r/query\s+([A-Za-z_]\w*)/, document) do
      [_, operation] -> operation
      _ -> nil
    end
  end

  defp operation_name(_), do: nil
end
