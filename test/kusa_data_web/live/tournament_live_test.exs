defmodule KusaDataWeb.TournamentLiveTest do
  use KusaDataWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KusaData.{Cache, Entrant, Event, Game, Player, Repo, Tournament, Tournaments}

  setup do
    game = Repo.insert!(Game.changeset(%Game{}, %{key: "melee", name: "Melee", videogame_id: 1}))

    tournament =
      Repo.insert!(Tournament.changeset(%Tournament{}, %{startgg_id: 1, slug: "t-genesis"}))

    event =
      Repo.insert!(
        Event.changeset(%Event{}, %{
          startgg_id: 1,
          name: "Melee Singles",
          tournament_id: tournament.id,
          game_id: game.id
        })
      )

    for {user_id, tag, standing} <- [{1, "Zain", 1}, {2, "Cody", 2}, {3, "Mango", 3}] do
      player =
        Repo.insert!(
          Player.changeset(%Player{}, %{user_id: user_id, player_id: user_id * 10, gamer_tag: tag})
        )

      Repo.insert!(
        Entrant.changeset(%Entrant{}, %{
          startgg_id: user_id,
          event_id: event.id,
          player_id: player.id,
          standing: standing
        })
      )
    end

    Application.put_env(:kusa_data, Cache, command: fn _commands -> {:error, :down} end)
    on_exit(fn -> Application.delete_env(:kusa_data, Cache) end)

    %{tournament: tournament}
  end

  defp with_fetch(fun) do
    Application.put_env(:kusa_data, Tournaments.API, fetch: fun)
    on_exit(fn -> Application.delete_env(:kusa_data, Tournaments.API) end)
  end

  test "renders the entrant roster by placement for a crawled tournament", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/tournaments/t-genesis")

    html = view |> element("#tournament-page") |> render()
    assert html =~ "Melee Singles"
    assert html =~ "Zain"
    assert html =~ "Cody"
    assert html =~ "Mango"
    assert html =~ "1"
    assert html =~ "2"
    assert html =~ "3"
  end

  test "shows an empty state for an unknown tournament slug", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/tournaments/t-nope")
    assert view |> element("#tournament-page") |> render() =~ "Tournament not crawled"
  end

  test "seed finder: rejects invalid URLs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/tournaments")

    view |> element("#seed-finder-form") |> render_submit(%{"url" => "not a url"})

    assert view |> element("#seed-finder") |> render() =~ "Enter a valid start.gg"
  end

  test "seed finder: lists events and then the seeding for the picked event", %{conn: conn} do
    with_fetch(fn query, variables ->
      cond do
        String.contains?(query, "TournamentEvents") ->
          assert variables == %{slug: "tournament/genesis-x2", videogameIds: [1]}

          {:ok,
           %{
             "tournament" => %{
               "id" => 7,
               "name" => "GENESIS X2",
               "events" => [%{"id" => 100, "name" => "Melee Singles", "slug" => "melee-singles"}]
             }
           }}

        String.contains?(query, "EventSeeding") ->
          assert variables == %{eventId: 100}

          {:ok,
           %{
             "event" => %{
               "id" => 100,
               "name" => "Melee Singles",
               "entrants" => %{
                 "nodes" => [
                   %{"id" => 1, "name" => "Zain", "seeds" => [%{"seedNum" => 1}]},
                   %{"id" => 2, "name" => "Cody", "seeds" => [%{"seedNum" => 2}]}
                 ]
               }
             }
           }}
      end
    end)

    {:ok, view, _html} = live(conn, ~p"/tournaments")

    view
    |> element("#seed-finder-form")
    |> render_submit(%{"url" => "https://start.gg/tournament/genesis-x2/events"})

    assert view |> element("#seed-finder") |> render() =~ "Melee Singles"

    view |> render_click("pick_event", %{"event_id" => "100"})

    html = view |> element("#seed-finder") |> render()
    assert html =~ "Zain"
    assert html =~ "Cody"
    assert html =~ "Seed"
  end

  test "seed finder: surfaces upstream errors", %{conn: conn} do
    with_fetch(fn _query, _variables -> {:error, {:http, 502}} end)
    {:ok, view, _html} = live(conn, ~p"/tournaments")

    view
    |> element("#seed-finder-form")
    |> render_submit(%{"url" => "https://start.gg/tournament/genesis-x2"})

    assert view |> element("#seed-finder") |> render() =~ "try again shortly"
  end
end
