defmodule KusaData.CrawlTest do
  use KusaData.DataCase, async: false

  import Plug.Conn

  alias KusaData.{Game, Player, Rating, Set, Tournament, Event, CrawlState}

  setup do
    bypass = Bypass.open()
    now = System.system_time(:second)

    Application.put_env(:kusa_data, KusaData.GraphQL.Client,
      endpoint: "http://localhost:#{bypass.port}/graphql",
      token: "test-token"
    )

    Application.put_env(:kusa_data, KusaData.GraphQL.RateLimiter,
      limit: 100_000,
      window_ms: 60_000
    )

    # no pacing in tests
    Application.put_env(:kusa_data, KusaData.Crawl, request_delay_ms: 0)

    %{bypass: bypass, now: now}
  end

  defp put_game do
    Repo.insert!(%Game{key: "melee", name: "Melee", videogame_id: 1})
  end

  test "crawls a tournament: persists data and advances state", %{bypass: bypass, now: now} do
    game = put_game()

    # Route requests by the GraphQL query name in the request body.
    Bypass.expect(bypass, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)

      query =
        if is_binary(body) do
          case Regex.run(~r/query (\w+)/, body) do
            [_all, name] -> name
            _ -> ""
          end
        else
          ""
        end

      response =
        case query do
          "RankingsTournamentPool" ->
            ~s({"data":{"tournaments":{"nodes":[
              {"id": 991, "slug": "/tournament/genesis-x"}
            ]}}})

          "RankingsGameEvent" ->
            ~s({"data":{"tournament":{"events":[
              {"id": 41, "name": "Melee Singles"},
              {"id": 42, "name": "Melee Doubles"}
            ]}}})

          "EventSets" ->
            ~s({"data":{"event":{"id":41,"name":"Melee Singles","sets":{
              "pageInfo":{"total":1,"totalPages":1},
              "nodes":[
                {"id": 500, "state":3,"completedAt":1672588800,"slots":[
                  {"entrant":{"participants":[{"gamerTag":"Mango","prefix":null,"user":{"id":1,"player":{"id":10}}}]},"standing":{"stats":{"score":{"value":2}}}},
                  {"entrant":{"participants":[{"gamerTag":"Mew2King","prefix":"C9","user":{"id":2,"player":{"id":20}}}]},"standing":{"stats":{"score":{"value":1}}}}
                ]}
              ]
            }}}})

          _ ->
            ~s({"errors":[{"message":"unexpected"}]})
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, response)
    end)

    assert {:ok, result} = KusaData.Crawl.run(game.id, now: now)

    assert %{tournaments: 1, sets_applied: 1, skipped_tournaments: 0, players: 2} = result

    # Tournament, event, set persisted
    assert Repo.aggregate(Tournament, :count, :id) == 1
    assert Repo.aggregate(Event, :count, :id) == 1
    set = Repo.one(Set) |> Repo.preload([:event])
    assert set.startgg_id == 500
    assert set.state == 3
    assert set.winner_score == 2

    # Two players + two ratings, with Elo applied (Mango wins the match)
    assert Repo.aggregate(Player, :count, :id) == 2
    rating_count = Repo.aggregate(Rating, :count, :id)
    assert rating_count == 2

    mango = Repo.get_by!(Player, user_id: 1)
    mango_rating = Repo.get_by!(Rating, game_id: game.id, player_id: mango.id)
    assert mango_rating.wins == 1
    assert mango_rating.losses == 0
    assert mango_rating.elo > 1500.0

    # Crawl state advanced + tournament marked seen
    state = Repo.one(CrawlState)
    assert 991 in state.seen_ids
    assert state.window_end == now
  end

  test "per-tournament error isolation: a failing event does not block the slice", %{
    bypass: bypass
  } do
    game = put_game()

    Bypass.expect(bypass, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)

      slug =
        Regex.run(~r/"tournamentSlug":"([^"]+)"/, body)
        |> then(fn
          [_all, slug] -> slug
          _ -> ""
        end)

      query =
        case Regex.run(~r/query (\w+)/, body) do
          [_all, name] -> name
          _ -> ""
        end

      response =
        case {query, slug} do
          {"RankingsTournamentPool", _} ->
            ~s({"data":{"tournaments":{"nodes":[
              {"id": 991, "slug": "/tournament/ok-one"},
              {"id": 992, "slug": "/tournament/bad-one"}
            ]}}})

          {"RankingsGameEvent", "/tournament/ok-one"} ->
            ~s({"data":{"tournament":{"events":[{"id":41,"name":"Singles"}]}}})

          {"RankingsGameEvent", "/tournament/bad-one"} ->
            # no event for this game => skipped, not fatal
            ~s({"data":{"tournament":{"events":[]}}})

          {"EventSets", _} ->
            ~s({"data":{"event":{"id":41,"name":"Singles","sets":{"pageInfo":{"total":0,"totalPages":1},"nodes":[]}}}})

          _ ->
            ~s({"errors":[{"message":"unexpected"}]})
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, response)
    end)

    assert {:ok, result} = KusaData.Crawl.run(game.id, now: System.system_time(:second))
    assert %{tournaments: 2, sets_applied: 0, skipped_tournaments: 1, players: 0} = result
    # only the ok tournament is marked seen; the bad one is retried next run
    state = Repo.one(CrawlState)
    assert 991 in state.seen_ids
    refute 992 in state.seen_ids
  end

  test "chronological application is path-independent", %{bypass: bypass} do
    game = put_game()

    Bypass.expect(bypass, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)

      query =
        case Regex.run(~r/query (\w+)/, body) do
          [_all, name] -> name
          _ -> ""
        end

      response =
        case query do
          "RankingsTournamentPool" ->
            ~s({"data":{"tournaments":{"nodes":[
              {"id": 991, "slug": "/tournament/gen-x"}
            ]}}})

          "RankingsGameEvent" ->
            ~s({"data":{"tournament":{"events":[{"id":41,"name":"Singles"}]}}})

          "EventSets" ->
            # Two cross-sets: A beats B, then B beats A (order deliberately reversed)
            ~s({"data":{"event":{"id":41,"name":"Singles","sets":{"pageInfo":{"total":2,"totalPages":1},"nodes":[
              {"id": 501, "state":3,"completedAt":"2023-01-02T12:00:00Z","slots":[
                {"entrant":{"participants":[{"gamerTag":"B","prefix":null,"user":{"id":2,"player":{"id":20}}}]},"standing":{"stats":{"score":{"value":2}}}},
                {"entrant":{"participants":[{"gamerTag":"A","prefix":null,"user":{"id":1,"player":{"id":10}}}]},"standing":{"stats":{"score":{"value":1}}}}
              ]},
              {"id": 500, "state":3,"completedAt":"2023-01-01T12:00:00Z","slots":[
                {"entrant":{"participants":[{"gamerTag":"A","prefix":null,"user":{"id":1,"player":{"id":10}}}]},"standing":{"stats":{"score":{"value":2}}}},
                {"entrant":{"participants":[{"gamerTag":"B","prefix":null,"user":{"id":2,"player":{"id":20}}}]},"standing":{"stats":{"score":{"value":1}}}}
              ]}
            ]}}}})

          _ ->
            ~s({"errors":[{"message":"unexpected"}]})
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, response)
    end)

    assert {:ok, %{sets_applied: 2, players: 2}} =
             KusaData.Crawl.run(game.id, now: System.system_time(:second))

    a = Repo.get_by!(Player, user_id: 1)
    b = Repo.get_by!(Player, user_id: 2)
    a_rating = Repo.get_by!(Rating, player_id: a.id)
    b_rating = Repo.get_by!(Rating, player_id: b.id)

    # After a win + a loss each, both land near their starting Elo (integer
    # rounding makes exact equality impossible, but the swap is symmetric).
    assert a_rating.elo + b_rating.elo >= 2998 and a_rating.elo + b_rating.elo <= 3002
    assert abs(a_rating.elo - 1500) <= 2 and abs(b_rating.elo - 1500) <= 2
    assert a_rating.wins == 1 and a_rating.losses == 1
    assert b_rating.wins == 1 and b_rating.losses == 1
  end
end
