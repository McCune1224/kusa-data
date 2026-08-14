defmodule KusaData.PlayersTest do
  use KusaData.DataCase

  alias KusaData.{Event, Game, Player, Players, Rating, Repo, Set, Tournament}

  setup do
    game = Repo.insert!(Game.changeset(%Game{}, %{key: "melee", name: "Melee", videogame_id: 1}))

    %{game: game}
  end

  defp seed_player do
    Repo.insert!(Player.changeset(%Player{}, %{user_id: 100, player_id: 1000, gamer_tag: "Kusa"}))
  end

  defp seed_set(game, winner, loser, completed_at, id) do
    tournament =
      Repo.insert!(Tournament.changeset(%Tournament{}, %{startgg_id: id, slug: "t-#{id}"}))

    event =
      Repo.insert!(
        Event.changeset(%Event{}, %{
          startgg_id: id,
          name: "Melee Singles",
          tournament_id: tournament.id,
          game_id: game.id
        })
      )

    Repo.insert!(
      Set.changeset(%Set{}, %{
        startgg_id: id,
        state: 3,
        completed_at: completed_at,
        event_id: event.id,
        winner_player_id: winner.id,
        loser_player_id: loser.id,
        winner_score: 3,
        loser_score: 1
      })
    )
  end

  test "get/1 returns nil for unknown players" do
    assert Players.get(999_999) == nil
  end

  test "sets/1 returns completed sets for the player, newest first, preloaded", %{game: game} do
    player = seed_player()

    rival =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: 200, player_id: 2000, gamer_tag: "Rival"})
      )

    third =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: 300, player_id: 3000, gamer_tag: "Third"})
      )

    old = ~U[2026-01-01 00:00:00Z]
    new = ~U[2026-01-05 00:00:00Z]
    seed_set(game, player, rival, old, 101)
    seed_set(game, rival, player, new, 102)
    seed_set(game, rival, third, new, 103)

    sets = Players.sets(player, 20)
    assert length(sets) == 2
    assert [newest, oldest] = sets
    assert newest.completed_at == new
    assert newest.winner_player_id == rival.id
    assert newest.loser_player_id == player.id
    assert newest.event.name == "Melee Singles"
    assert newest.event.tournament.slug =~ "t-"
  end

  test "sets/1 respects the limit and ignores non-completed sets", %{game: game} do
    player = seed_player()

    rival =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: 200, player_id: 2000, gamer_tag: "Rival"})
      )

    for day <- 1..5 do
      seed_set(
        game,
        player,
        rival,
        ~U[2026-01-01 00:00:00Z] |> DateTime.add(day * 3600, :second),
        200 + day
      )
    end

    assert length(Players.sets(player, 3)) == 3
  end

  test "rating/2 returns the rating for the game", %{game: game} do
    player = seed_player()

    Repo.insert!(
      Rating.changeset(%Rating{}, %{
        game_id: game.id,
        player_id: player.id,
        elo: 1500,
        sets: 1,
        wins: 1,
        losses: 0
      })
    )

    assert Players.rating(game, player).elo == 1500
    assert Players.rating(game, player).sets == 1
  end
end
