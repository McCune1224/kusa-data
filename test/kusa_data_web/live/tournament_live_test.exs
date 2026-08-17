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
            %{"id" => 101, "name" => "Melee Singles", "numEntrants" => 32, "state" => 1},
            %{"id" => 102, "name" => "Melee Doubles", "numEntrants" => 8, "state" => 3}
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
end
