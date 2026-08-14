defmodule KusaData.Rankings do
  @moduledoc """
  Leaderboard reads over the crawled `ratings` table. Returns the same
  player map shape as `KusaData.Search` (`player_db_id`, `gamer_tag`,
  `prefix`, `user_id`, `player_id`, `elo`, plus wins/losses/sets) so every
  page renders players identically.
  """

  alias KusaData.{Game, Player, Rating, Repo, Search}

  import Ecto.Query

  @default_limit 100

  @doc "The top `limit` players for `game`, Elo descending."
  @spec top(Game.t(), pos_integer) :: [map]
  def top(game, limit \\ @default_limit) do
    from(r in Rating,
      join: p in Player,
      on: p.id == r.player_id,
      where: r.game_id == ^game.id,
      order_by: [desc: r.elo],
      limit: ^limit,
      select: %{
        player_db_id: p.id,
        user_id: p.user_id,
        player_id: p.player_id,
        gamer_tag: p.gamer_tag,
        prefix: p.prefix,
        elo: r.elo,
        wins: r.wins,
        losses: r.losses,
        sets: r.sets
      }
    )
    |> Repo.all()
  end

  @doc """
  Ranked players matching `query` (the search index ranking: exact > prefix >
  substring, ties by Elo). Blank queries return `[]` — callers show the top
  list instead.
  """
  @spec search(Game.t(), String.t(), pos_integer) :: [map]
  def search(game, query, limit \\ @default_limit) do
    game
    |> Search.search_index(query)
    |> Enum.take(limit)
    |> Enum.map(&attach_record(game, &1))
  end

  defp attach_record(game, %{player_db_id: db_id} = result) do
    case Repo.get_by(Rating, game_id: game.id, player_id: db_id) do
      nil -> result
      rating -> Map.merge(result, %{wins: rating.wins, losses: rating.losses, sets: rating.sets})
    end
  end
end
