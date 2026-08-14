defmodule KusaData.Players do
  @moduledoc """
  Player page reads: player lookup, per-game rating, and completed set
  history with opponent/event context. Stat computations live in
  `KusaData.Stats`; game-level detail comes from `KusaData.SetDetails`.
  """

  alias KusaData.{Player, Rating, Repo, Set}

  import Ecto.Query

  @doc "The player by internal id, or nil."
  @spec get(integer) :: Player.t() | nil
  def get(id), do: Repo.get(Player, id)

  @doc "The player's rating for `game`, or nil."
  @spec rating(Game.t(), Player.t()) :: Rating.t() | nil
  def rating(game, player), do: Repo.get_by(Rating, game_id: game.id, player_id: player.id)

  @doc """
  The player's completed sets, newest first, with winner/loser players and
  event + tournament preloaded. Byes (no loser) are included; callers decide
  how to present them.
  """
  @spec sets(Player.t(), pos_integer) :: [Set.t()]
  def sets(player, limit \\ 50) do
    from(s in Set,
      where:
        s.state == 3 and (s.winner_player_id == ^player.id or s.loser_player_id == ^player.id),
      order_by: [desc: s.completed_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Repo.preload([:winner, :loser, event: :tournament])
  end
end
