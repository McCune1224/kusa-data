defmodule KusaData.SearchTest do
  use KusaData.DataCase, async: false

  alias KusaData.{Game, Player, Rating, Repo, Search}

  setup do
    Application.put_env(:kusa_data, KusaData.GraphQL.RateLimiter,
      limit: 100_000,
      window_ms: 60_000
    )

    Application.put_env(:kusa_data, KusaData.Crawl, request_delay_ms: 0)
    :ok
  end

  defp seed_game do
    Repo.insert!(%Game{key: "melee", name: "Melee", videogame_id: 1})
  end

  defp seed_player(attrs) do
    Repo.insert!(Player.changeset(%Player{}, attrs))
  end

  defp qname(body) do
    case Regex.run(~r/query (\w+)/, body) do
      [_all, name] -> name
      _ -> "NOQ"
    end
  end

  defp seed_rating(game, player_id, elo) do
    Repo.insert!(
      Rating.changeset(%Rating{}, %{
        game_id: game.id,
        player_id: player_id,
        elo: elo,
        sets: 5,
        wins: 3,
        losses: 2
      })
    )
  end

  test "returns exact, prefix, then substring matches in that order" do
    game = seed_game()

    a = seed_player(%{user_id: 1, player_id: 10, gamer_tag: "Mango"})
    b = seed_player(%{user_id: 2, player_id: 20, gamer_tag: "MangoTheBeast"})
    c = seed_player(%{user_id: 3, player_id: 30, gamer_tag: "PewPewMango"})
    seed_rating(game, a.id, 1700)
    seed_rating(game, b.id, 1600)
    seed_rating(game, c.id, 1500)

    results = Search.search(game, "mango")
    assert [a_uid, b_uid, c_uid] = Enum.map(results, & &1.user_id)
    assert a_uid == 1 and b_uid == 2 and c_uid == 3
  end

  test "prefix match outranks higher-elo substring match" do
    game = seed_game()

    prefix = seed_player(%{user_id: 1, player_id: 10, gamer_tag: "Armada"})
    substring = seed_player(%{user_id: 2, player_id: 20, gamer_tag: "SSBMZainArmadaKing"})
    seed_rating(game, prefix.id, 1500)
    seed_rating(game, substring.id, 1800)

    results = Search.search(game, "armada")
    assert Enum.map(results, & &1.user_id) == [1, 2]
  end

  test "ties break by elo descending" do
    game = seed_game()

    a = seed_player(%{user_id: 1, player_id: 10, gamer_tag: "Mango"})
    b = seed_player(%{user_id: 2, player_id: 20, gamer_tag: "Mango"})
    seed_rating(game, a.id, 1750)
    seed_rating(game, b.id, 1650)

    results = Search.search(game, "mango")
    assert Enum.map(results, & &1.user_id) == [1, 2]
  end

  test "does not include players without a match" do
    game = seed_game()

    mango = seed_player(%{user_id: 1, player_id: 10, gamer_tag: "Mango"})
    seed_player(%{user_id: 2, player_id: 20, gamer_tag: "Leffen"})
    seed_rating(game, mango.id, 1600)

    assert Search.search(game, "mango") |> Enum.map(& &1.user_id) == [1]
  end

  test "returns empty for a blank query" do
    game = seed_game()
    assert Search.search(game, "") == []
    assert Search.search(game, "   ") == []
  end

  test "falls back to live start.gg when index has no exact match" do
    bypass = Bypass.open()

    Application.put_env(:kusa_data, KusaData.GraphQL.Client,
      endpoint: "http://localhost:#{bypass.port}/graphql",
      token: "test-token"
    )

    game = seed_game()
    seed_player(%{user_id: 1, player_id: 10, gamer_tag: "Zain", prefix: "Mango"})

    Bypass.expect(bypass, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)

      response =
        case qname(body) do
          "RecentTournaments" ->
            ~s({"data":{"tournaments":{"nodes":[{"slug":"/t/gen"}]}}})

          "SearchParticipants" ->
            ~s({"data":{"tournament":{"participants":{"nodes":[
              {"id": 5, "gamerTag": "Westballz", "prefix": null,
                "user": {"id": 999, "player": {"id": 990}}}
            ]}}}})

          _ ->
            ~s({"errors":[{"message":"unexpected"}]})
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, response)
    end)

    # "westballz" is not in the index => the live scan finds it.
    results = Search.search(game, "westballz")
    assert Enum.map(results, & &1.user_id) == [999]
    assert hd(results).gamer_tag == "Westballz"
  end

  test "matches on prefix as well as gamer tag" do
    game = seed_game()

    exact = seed_player(%{user_id: 1, player_id: 10, gamer_tag: "Zain", prefix: "Mango"})
    seed_rating(game, exact.id, 1500)

    results = Search.search(game, "mango")
    assert Enum.map(results, & &1.user_id) == [1]
    refute results == []
  end

  test "search_index is index-only and never hits start.gg" do
    game = seed_game()

    a = seed_player(%{user_id: 1, player_id: 10, gamer_tag: "Mango"})
    b = seed_player(%{user_id: 2, player_id: 20, gamer_tag: "Leffen"})
    seed_rating(game, a.id, 1750)
    seed_rating(game, b.id, 1600)

    # No Bypass started => if search_index tried the live fallback it would
    # raise (no endpoint configure). It must stay purely on Postgres.
    assert Search.search_index(game, "mango") |> Enum.map(& &1.user_id) == [1]
    assert Search.search_index(game, "leffen") |> Enum.map(& &1.user_id) == [2]
    assert Search.search_index(game, "westballz") == []
  end
end
