defmodule KusaData.Players do
  @moduledoc """
  Player profile lookup from start.gg.
  """

  @identity_ttl 15 * 60

  alias KusaData.Cache
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries

  @spec profile(integer()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def profile(player_id) do
    Cache.fetch("player:#{player_id}:identity", @identity_ttl, fn ->
      {document, variables} = Queries.player_identity(player_id)

      with {:ok, data} <- Client.query(document, variables),
           %{"player" => %{} = player} <- data do
        {:ok,
         %{
           "player_id" => player["id"],
           "gamer_tag" => player["gamerTag"],
           "user_id" => player["user"]["id"]
         }}
      else
        %{"player" => nil} -> {:error, :not_found}
        _ -> {:error, :unexpected_response}
      end
    end)
  end
end
