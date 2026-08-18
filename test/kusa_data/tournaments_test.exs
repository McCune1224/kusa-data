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

  describe "browse/1 contract" do
    test "upcoming mode defaults to melee and round-trips through the cache" do
      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response([Fixtures.tournament(1)], 1)
      )

      assert {:ok, result, :miss} = Tournaments.browse(%{mode: :upcoming, page: 1})
      assert length(result["tournaments"]) == 1

      FakeTransport.put(:query, "TournamentSearch", Fixtures.tournament_search_response([], 0))
      assert {:ok, %{"total" => 1}, :hit} = Tournaments.browse(%{mode: :upcoming, page: 1})
    end

    test "games: :all omits the game restriction and uses a distinct cache key" do
      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response([Fixtures.tournament(2)], 1)
      )

      assert {:ok, result, :miss} = Tournaments.browse(%{mode: :upcoming, games: :all})
      assert length(result["tournaments"]) == 1

      # A melee-only query must not reuse the all-games cache entry.
      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response([Fixtures.tournament(3)], 1)
      )

      assert {:ok, _, :miss} = Tournaments.browse(%{mode: :upcoming, games: ["melee"]})
      assert {:ok, _, :hit} = Tournaments.browse(%{mode: :upcoming, games: :all})
    end

    test "different filters never share a cache entry" do
      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response([Fixtures.tournament(1)], 1)
      )

      assert {:ok, _, :miss} = Tournaments.browse(%{mode: :upcoming, page: 1})
      assert {:ok, _, :miss} = Tournaments.browse(%{mode: :upcoming, page: 2})
      assert {:ok, _, :miss} = Tournaments.browse(%{mode: :past, from: "2026-01-01"})
      assert {:ok, _, :miss} = Tournaments.browse(%{mode: :past, results_only: true})
      assert {:ok, _, :miss} = Tournaments.browse(%{mode: :search, q: "genesis"})
      assert {:ok, _, :hit} = Tournaments.browse(%{mode: :upcoming, page: 1})
    end

    test "past mode sends ISO date bounds and filters completed tournaments" do
      nodes = [
        Fixtures.tournament(1, %{"events" => [%{"id" => 101, "numEntrants" => 8, "state" => 3}]}),
        Fixtures.tournament(2, %{"events" => [%{"id" => 102, "numEntrants" => 8, "state" => 1}]}),
        Fixtures.tournament(3, %{"events" => [%{"id" => 103, "numEntrants" => 8}]})
      ]

      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response(nodes, 3)
      )

      assert {:ok, result, :miss} =
               Tournaments.browse(%{
                 mode: :past,
                 from: "2026-01-01",
                 to: "2026-01-31",
                 results_only: true
               })

      assert length(result["tournaments"]) == 1
      assert hd(result["tournaments"])["id"] == 1
    end

    test "past mode paginates upstream pages until the requested page fills" do
      page1 =
        Enum.map(1..24, fn i ->
          Fixtures.tournament(i, %{"events" => [%{"id" => i, "numEntrants" => 4, "state" => 3}]})
        end)

      page2 =
        Enum.map(25..28, fn i ->
          Fixtures.tournament(i, %{"events" => [%{"id" => i, "numEntrants" => 4, "state" => 3}]})
        end)

      FakeTransport.put(
        :query,
        "TournamentSearch",
        fn
          1 -> Fixtures.tournament_search_response(page1, 28, total_pages: 2)
          2 -> Fixtures.tournament_search_response(page2, 28, total_pages: 2)
        end
      )

      # Page 2 needs 48 results; both upstream pages are consumed.
      assert {:ok, result, :miss} =
               Tournaments.browse(%{mode: :past, results_only: true, page: 2})

      assert length(result["tournaments"]) == 4
      assert result["total"] == 28
    end

    test "search mode matches by name/city/venue terms" do
      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response([Fixtures.tournament(9)], 1)
      )

      assert {:ok, result, :miss} = Tournaments.browse(%{mode: :search, q: "genesis"})
      assert hd(result["tournaments"])["id"] == 9
    end

    test "empty search terms return an empty page without querying upstream" do
      assert {:ok, %{"total" => 0, "tournaments" => []}, :miss} =
               Tournaments.browse(%{mode: :search, q: ""})
    end

    test "region mode filters by country and state" do
      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response([Fixtures.tournament(4)], 1)
      )

      assert {:ok, result, :miss} =
               Tournaments.browse(%{mode: :region, country: "US", state: "IL"})

      assert hd(result["tournaments"])["id"] == 4
    end

    test "regions derives a country/state index from recent tournaments" do
      FakeTransport.put(
        :query,
        "TournamentSearch",
        Fixtures.tournament_search_response(
          [
            Fixtures.tournament(1, %{
              "countryCode" => "US",
              "addrState" => "IL",
              "numAttendees" => 64
            }),
            Fixtures.tournament(2, %{
              "countryCode" => "US",
              "addrState" => "CA",
              "numAttendees" => 128
            }),
            Fixtures.tournament(3, %{"countryCode" => "US", "addrState" => nil})
          ],
          3
        )
      )

      assert {:ok, regions, :miss} = Tournaments.regions()
      assert length(regions) == 3
      assert Enum.find(regions, &(&1["state"] == "CA"))["tournaments"] == 1
      assert Enum.find(regions, &(&1["state"] == "IL"))["tournaments"] == 1
      assert Enum.find(regions, &(&1["state"] == nil))["country"] == "US"
    end
  end
end
