defmodule KusaDataWeb.TournamentLiveTest do
  use KusaDataWeb.ConnCase

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  import Phoenix.LiveViewTest
  import KusaData.Test.LiveViewHelpers

  test "renders the tournament header and streams its melee events", %{conn: conn} do
    tournament =
      Fixtures.tournament(
        1,
        %{
          "name" => "Test Melee Weekly",
          "events" => [
            %{
              "id" => 101,
              "name" => "Melee Singles",
              "numEntrants" => 32,
              "state" => 1,
              "videogame" => %{"id" => 1, "name" => "Super Smash Bros. Melee", "slug" => "melee"}
            },
            %{
              "id" => 102,
              "name" => "Melee Doubles",
              "numEntrants" => 8,
              "state" => 3,
              "videogame" => %{"id" => 1, "name" => "Super Smash Bros. Melee", "slug" => "melee"}
            }
          ]
        }
      )

    FakeTransport.put(:query, "TournamentDetail", Fixtures.tournament_detail_response(tournament))

    {:ok, view, _html} = live(conn, "/tournament/test-melee-weekly")

    assert wait_has_element(view, "#event-101")
    assert element(view, "h1") |> render() =~ "Test Melee Weekly"
    assert has_element?(view, "#events")
    assert has_element?(view, "#event-102")
  end

  test "shows an empty state for unknown slugs", %{conn: conn} do
    FakeTransport.put(:query, "TournamentDetail", %{"data" => %{"tournament" => nil}})

    {:ok, view, _html} = live(conn, "/tournament/nope")

    assert wait_has_element(view, "h3")
    assert element(view, "h3") |> render() =~ "No tournament with that slug was found"
  end

  describe "multi-game events" do
    setup do
      KusaData.Games.register(%{
        slug: "ultimate",
        videogame_id: 1386,
        name: "Super Smash Bros. Ultimate",
        short_name: "Ultimate"
      })

      tournament =
        Fixtures.tournament(
          1,
          %{
            "name" => "Test Multi-Game Major",
            "events" => [
              %{
                "id" => 101,
                "name" => "Melee Singles",
                "numEntrants" => 32,
                "state" => 3,
                "videogame" => %{
                  "id" => 1,
                  "name" => "Super Smash Bros. Melee",
                  "slug" => "melee"
                }
              },
              %{
                "id" => 201,
                "name" => "Ultimate Singles",
                "numEntrants" => 128,
                "state" => 3,
                "videogame" => %{
                  "id" => 1386,
                  "name" => "Super Smash Bros. Ultimate",
                  "slug" => "ultimate"
                }
              }
            ]
          }
        )

      FakeTransport.put(
        :query,
        "TournamentDetail",
        Fixtures.tournament_detail_response(tournament)
      )

      :ok
    end

    test "all games render under ?game=all with both event cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tournament/test-multi-game-major?game=all")

      assert wait_has_element(view, "#event-101")
      assert wait_has_element(view, "#event-201")
      assert render(view) =~ "All games"
      assert render(view) =~ "Ultimate"
    end

    test "melee remains the default and hides other games", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tournament/test-multi-game-major")

      assert wait_has_element(view, "#event-101")
      refute has_element?(view, "#event-201")
    end

    test "a selected game hides other events and preserves the toggle link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tournament/test-multi-game-major?game=ultimate")

      assert wait_has_element(view, "#event-201")
      refute has_element?(view, "#event-101")
      assert has_element?(view, "a[href='/tournament/test-multi-game-major?game=all']")
    end

    test "unknown game params fall back to the melee default", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tournament/test-multi-game-major?game=dota-2")

      assert wait_has_element(view, "#event-101")
      refute has_element?(view, "#event-201")
    end

    test "event cards link to game-scoped event pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tournament/test-multi-game-major?game=all")

      assert wait_has_element(view, "#event-201")
      assert has_element?(view, "a[href='/event/201?tab=seeds&game=ultimate']")
    end
  end
end
