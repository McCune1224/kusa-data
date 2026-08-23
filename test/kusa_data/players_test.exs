defmodule KusaData.PlayersTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Players
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  setup do
    FakeTransport.put(
      :query,
      "PlayerIdentity",
      Fixtures.player_identity_response(100, "Mango", 10)
    )

    :ok
  end

  test "profile extracts prefix, location, and avatar" do
    FakeTransport.put(
      :query,
      "PlayerIdentity",
      Fixtures.player_identity_response(100, "Mango", 10, %{
        "data" => %{
          "player" => %{
            "id" => 100,
            "gamerTag" => "Mango",
            "prefix" => "EG",
            "user" => %{
              "id" => 10,
              "name" => "Joseph",
              "bio" => "The GOAT.",
              "location" => %{"city" => "Tustin", "state" => "CA", "country" => "US"},
              "images" => [%{"url" => "https://example.com/mango.png"}]
            }
          }
        }
      })
    )

    assert {:ok, profile, :miss} = Players.profile(100)
    assert profile["prefix"] == "EG"
    assert profile["user_name"] == "Joseph"
    assert profile["bio"] == "The GOAT."
    assert profile["location"] == "Tustin, CA, US"
    assert profile["avatar_url"] == "https://example.com/mango.png"
  end

  test "profile tolerates missing user fields" do
    assert {:ok, profile, :miss} = Players.profile(100)
    assert profile["prefix"] == nil
    assert profile["location"] == nil
    assert profile["avatar_url"] == nil
  end

  test "history fetches the full set history without six-page truncation" do
    # 10 pages of 40 sets: the old summary cap was 6 pages.
    FakeTransport.put(
      :query,
      "PlayerSets",
      fn page ->
        Fixtures.player_sets_response(
          Enum.map(((page - 1) * 40 + 1)..(page * 40)//1, fn i -> Fixtures.set(i, 1, 2, 1) end),
          400
        )
      end
    )

    assert {:ok, history, :miss} = Players.history(100)
    assert history["total"] == 400
    assert history["fetched"] == 400
    assert history["continuation"] == nil
    assert history["gamer_tag"] == "Mango"
  end

  test "history returns a continuation when the page budget is exhausted" do
    # 60 pages total (well beyond the 50-page budget).
    total = 3000

    FakeTransport.put(:query, "PlayerSets", fn page ->
      nodes =
        Enum.map(((page - 1) * 50 + 1)..(page * 50)//1, fn i -> Fixtures.set(i, 1, 2, 1) end)

      %{
        "data" => %{
          "player" => %{
            "id" => 1,
            "gamerTag" => "Mango",
            "sets" => %{
              "nodes" => nodes,
              "pageInfo" => %{"total" => total, "totalPages" => div(total, 50)}
            }
          }
        }
      }
    end)

    assert {:ok, history, :miss} = Players.history(100)
    assert history["fetched"] == 2500
    assert history["continuation"] == 51
  end

  test "history filters by opponent player id and game" do
    ultimate_event = %{
      "id" => 200,
      "name" => "Ultimate Singles",
      "videogame" => %{"id" => 1386, "name" => "Super Smash Bros. Ultimate", "slug" => "ultimate"}
    }

    # Set 2's opponent is a third player (300), not player 200.
    sets = [
      Fixtures.set(1, 1, 2, 1),
      Fixtures.set(2, 1, 3, 3, %{
        "slots" => [Fixtures.slot(1, "Mango", 10, 100), Fixtures.slot(3, "Plup", 30, 300)]
      }),
      Fixtures.set(3, 1, 2, 1, %{"event" => ultimate_event})
    ]

    FakeTransport.put(:query, "PlayerSets", Fixtures.player_sets_response(sets))

    assert {:ok, history, :miss} = Players.history(100, %{opponent: 200})
    assert Enum.map(history["sets"], & &1["id"]) == [1, 3]

    assert {:ok, history, :miss} = Players.history(100, %{game: "ultimate"})
    assert Enum.map(history["sets"], & &1["id"]) == [3]
  end

  test "head_to_head joins on player id and reports unresolved separately" do
    # A's sets vs B (player 200), plus one set vs an unresolved name-only slot.
    a_sets = [
      Fixtures.set(1, 1, 2, 1),
      Fixtures.set(2, 1, 2, 2)
    ]

    b_sets = [Fixtures.set(3, 2, 1, 2)]

    FakeTransport.put(:query, "PlayerSets", fn
      1 -> Fixtures.player_sets_response(a_sets)
      _ -> Fixtures.player_sets_response(b_sets)
    end)

    assert {:ok, data, :miss} = Players.head_to_head(100, 200)
    assert data["sets"] == 3
    assert data["player_a_wins"] == 2
    assert data["player_b_wins"] == 1
    assert data["unresolved_sets"] == 0
  end

  test "h2h reports name-only rows as unresolved without counting them" do
    FakeTransport.put(:query, "PlayerIdentity", fn
      1 -> Fixtures.player_identity_response(100, "Mango", 10)
      _ -> Fixtures.player_identity_response(200, "Armada", 20)
    end)

    # A set where the opponent slot matches "Armada" by name but has no player
    # id: reported separately, never attributed to player B.
    name_only =
      Fixtures.set(1, 1, 2, 1)
      |> Map.put("slots", [
        Fixtures.slot(1, "Mango", 10, 100),
        Fixtures.slot(2, "Armada", 21)
      ])

    FakeTransport.put(:query, "PlayerSets", fn
      1 -> Fixtures.player_sets_response([name_only])
      _ -> Fixtures.player_sets_response([])
    end)

    assert {:ok, data, :miss} = Players.head_to_head(100, 200)
    assert data["sets"] == 0
    assert data["unresolved_sets"] == 1
    assert data["player_a_wins"] == 0
    assert data["player_b_wins"] == 0
  end

  test "compare builds side-by-side records with h2h" do
    a_sets = [Fixtures.set(1, 1, 2, 1), Fixtures.set(2, 1, 2, 2)]
    b_sets = [Fixtures.set(3, 2, 1, 2), Fixtures.set(4, 2, 1, 1)]

    FakeTransport.put(:query, "PlayerSets", fn
      1 -> Fixtures.player_sets_response(a_sets)
      _ -> Fixtures.player_sets_response(b_sets)
    end)

    assert {:ok, data, :miss} = Players.compare(100, 200)

    [a, b] = data["players"]
    assert a["player_id"] == 100
    assert a["wins"] == 1
    assert a["losses"] == 1
    assert b["wins"] == 1
    assert data["head_to_head"]["sets"] == 4
  end

  test "trend buckets are chronological with win rate and best placement" do
    sets = [
      Fixtures.set(1, 1, 2, 1),
      Fixtures.set(2, 1, 2, 2),
      Fixtures.set(3, 1, 2, 1, %{"completedAt" => 1_781_000_000})
    ]

    FakeTransport.put(:query, "PlayerSets", Fixtures.player_sets_response(sets))

    assert {:ok, trend, :miss} = Players.trend(100)

    months = Enum.map(trend["buckets"], & &1["month"])
    assert months == Enum.sort(months)
    assert length(trend["buckets"]) >= 1
  end
end
