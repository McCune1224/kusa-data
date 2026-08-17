defmodule KusaData.GraphQL.Transport do
  @moduledoc """
  Minimal HTTP transport contract for outbound API calls.

  Implementations return `{:ok, %{status: integer, body: term}}` for any
  received response (including non-2xx) and `{:error, reason}` only for
  network-level failures, so callers can shape their own retry logic.
  """

  @callback post(url :: String.t(), body :: map(), headers :: list()) ::
              {:ok, %{status: integer(), body: term()}} | {:error, term()}

  @callback get(url :: String.t(), headers :: list()) ::
              {:ok, %{status: integer(), body: term()}} | {:error, term()}
end
