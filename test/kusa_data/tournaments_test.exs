defmodule KusaData.TournamentsTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures
  alias KusaData.Tournaments

  use KusaData.Test.Doubles

  setup do
    FakeTransport.put(
      :url,
      "zippopotam.us/us/60614",
      Fixtures.zippopotam_response(41.9208, -87.6488, "Chicago", "IL")
    )

    :ok
  end

  test "upcoming lists tournaments with total" do
    nodes = [Fixtures.tournament(1), Fixtures.tournament(2)]
    FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response(nodes, 2))

    assert {:ok, result, :miss} = Tournaments.upcoming(1)
    assert length(result["tournaments"]) == 2
    assert result["total"] == 2
    assert hd(result["tournaments"])["name"] == "Test Melee Weekly"
  end

  test "nearby geocodes, queries with coordinates, and attaches the place" do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(7)], 1)
    )

    assert {:ok, result, :miss} = Tournaments.nearby("60614", "50mi", 1)
    assert result["total"] == 1
    assert result["place"]["city"] == "Chicago"
    assert hd(result["tournaments"])["id"] == 7
  end

  test "nearby is cached per zip and radius" do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(7)], 1)
    )

    assert {:ok, _, :miss} = Tournaments.nearby("60614", "50mi", 1)

    FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response([], 0))

    assert {:ok, %{"total" => 1}, :hit} = Tournaments.nearby("60614", "50mi", 1)
    assert {:ok, %{"total" => 0}, :miss} = Tournaments.nearby("60614", "100mi", 1)
  end

  test "unknown zips propagate the geocode error" do
    FakeTransport.put(:url, "zippopotam.us", %{status: 404})
    FakeTransport.put(:url, "geocoding-api.open-meteo.com", %{"results" => []})

    assert {:error, :not_found} = Tournaments.nearby("00000", "50mi", 1)
  end

  test "upstream errors after a successful geocode don't crash" do
    FakeTransport.put(:query, "TournamentSearch", %{error: :upstream_broke})

    assert {:error, :upstream_broke} = Tournaments.nearby("60614", "50mi", 1)
  end

  test "by_slug returns tournament detail and errors on missing tournaments" do
    FakeTransport.put(
      :query,
      "TournamentDetail",
      Fixtures.tournament_detail_response(Fixtures.tournament(1))
    )

    assert {:ok, tournament, :miss} = Tournaments.by_slug("tournament/test-melee-weekly")
    assert tournament["name"] == "Test Melee Weekly"

    FakeTransport.put(:query, "TournamentDetail", %{"data" => %{"tournament" => nil}})
    assert {:error, :not_found} = Tournaments.by_slug("tournament/does-not-exist")
  end

  test "invalidate clears cached nearby pages" do
    FakeTransport.put(
      :query,
      "TournamentSearch",
      Fixtures.tournament_search_response([Fixtures.tournament(7)], 1)
    )

    assert {:ok, _, :miss} = Tournaments.nearby("60614", "50mi", 1)

    Tournaments.invalidate("60614", "50mi")

    FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response([], 0))
    assert {:ok, %{"total" => 0}, :miss} = Tournaments.nearby("60614", "50mi", 1)
  end
end
