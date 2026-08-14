defmodule KusaData.RankingsTest do
  use KusaData.DataCase

  alias KusaData.{Game, Player, Rankings, Rating, Repo}

  import Ecto.Query

  setup do
    game = Repo.insert!(Game.changeset(%Game{}, %{key: "melee", name: "Melee", videogame_id: 1}))
    %{game: game}
  end

  defp seed(game, user_id, tag, elo) do
    player =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: user_id, player_id: user_id * 10, gamer_tag: tag})
      )

    Repo.insert!(
      Rating.changeset(%Rating{}, %{
        game_id: game.id,
        player_id: player.id,
        elo: elo,
        sets: 10,
        wins: 6,
        losses: 4
      })
    )
  end

  test "top/2 orders by elo descending with W/L attached", %{game: game} do
    seed(game, 1, "Mango", 1600)
    seed(game, 2, "Armada", 1700)
    seed(game, 3, "Hungrybox", 1500)

    assert [%{gamer_tag: "Armada"}, %{gamer_tag: "Mango"}, %{gamer_tag: "Hungrybox"}] =
             Rankings.top(game, 10)
  end

  test "top/2 respects the limit", %{game: game} do
    for i <- 1..5, do: seed(game, i, "Player#{i}", 1000 + i)
    assert length(Rankings.top(game, 3)) == 3
  end

  test "search/2 ranks matches and attaches W/L", %{game: game} do
    seed(game, 1, "Mango", 1600)
    seed(game, 2, "MangoTheBeast", 1700)

    assert [%{gamer_tag: "Mango"}, %{gamer_tag: "MangoTheBeast"}] =
             Rankings.search(game, "mango", 10)

    assert hd(Rankings.search(game, "mango", 10)).sets == 10
  end

  test "search/2 returns [] for a blank query", %{game: game} do
    assert Rankings.search(game, "  ", 10) == []
  end
end
