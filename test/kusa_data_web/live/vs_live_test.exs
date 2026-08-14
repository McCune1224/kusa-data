defmodule KusaDataWeb.VSLiveTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KusaData.{Event, Game, Player, Rating, Repo, Set, Tournament}

  setup do
    game = Repo.insert!(Game.changeset(%Game{}, %{key: "melee", name: "Melee", videogame_id: 1}))

    mango =
      seed_player(game, 1, "Mango", 1700)
      |> then(fn {player, _} -> player end)

    armada = seed_player(game, 2, "Armada", 1600) |> elem(0)

    tournament =
      Repo.insert!(Tournament.changeset(%Tournament{}, %{startgg_id: 1, slug: "t-vs"}))

    event =
      Repo.insert!(
        Event.changeset(%Event{}, %{
          startgg_id: 1,
          name: "Melee Singles",
          tournament_id: tournament.id,
          game_id: game.id
        })
      )

    for {id, winner, loser, date} <- [
          {11, mango.id, armada.id, ~U[2026-01-01 00:00:00Z]},
          {12, armada.id, mango.id, ~U[2026-01-02 00:00:00Z]},
          {13, mango.id, armada.id, ~U[2026-01-03 00:00:00Z]}
        ] do
      Repo.insert!(
        Set.changeset(%Set{}, %{
          startgg_id: id,
          state: 3,
          completed_at: date,
          event_id: event.id,
          winner_player_id: winner,
          loser_player_id: loser,
          winner_score: 3,
          loser_score: 1
        })
      )
    end

    %{mango: mango, armada: armada}
  end

  defp seed_player(game, user_id, tag, elo) do
    player =
      Repo.insert!(
        Player.changeset(%Player{}, %{user_id: user_id, player_id: user_id * 10, gamer_tag: tag})
      )

    rating =
      Repo.insert!(
        Rating.changeset(%Rating{}, %{
          game_id: game.id,
          player_id: player.id,
          elo: elo,
          sets: 3,
          wins: 2,
          losses: 1
        })
      )

    {player, rating}
  end

  test "renders two empty panels", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/vs")

    html = view |> element("#vs-page") |> render()
    assert html =~ "1P"
    assert html =~ "2P"
    assert html =~ "Pick two players"
  end

  test "searching and selecting players shows stats and the h2h record", %{
    conn: conn,
    mango: mango,
    armada: armada
  } do
    {:ok, view, _html} = live(conn, ~p"/vs")

    # Panel A: search + select Mango
    view |> element("#vs-search-a") |> render_submit(%{"query" => "mango"})
    assert view |> element("#vs-results-a") |> render() =~ "Mango"

    view |> render_click("select", %{"side" => "a", "id" => mango.id})

    # Panel B: search + select Armada
    view |> element("#vs-search-b") |> render_submit(%{"query" => "armada"})
    view |> render_click("select", %{"side" => "b", "id" => armada.id})

    html = view |> element("#vs-page") |> render()
    assert html =~ "Mango"
    assert html =~ "Armada"
    assert html =~ "1700"
    assert html =~ "1600"
    assert html =~ "2-1"
    assert html =~ "Head-to-head"
  end

  test "no-match search shows an empty hint", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/vs")
    view |> element("#vs-search-a") |> render_submit(%{"query" => "zzzzz"})
    assert view |> element("#vs-results-a") |> render() =~ "No matches"
  end
end
