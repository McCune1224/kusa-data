defmodule KusaData.GamesTest do
  use ExUnit.Case, async: true

  import KusaData.Test.Doubles

  alias KusaData.Games
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  test "melee is the seeded default" do
    assert Games.default()[:slug] == "melee"
    assert Games.by_slug("melee")[:videogame_id] == 1
    assert Games.by_id(1)[:slug] == "melee"
  end

  test "normalize derives game records from videogame payloads" do
    game =
      Games.normalize(
        Fixtures.videogame(1386, "ultimate", "Super Smash Bros. Ultimate", "Ultimate")
      )

    assert game[:slug] == "ultimate"
    assert game[:videogame_id] == 1386
    assert Games.by_slug("ultimate")[:short_name] == "Ultimate"
    assert Games.ids_for_slugs(["melee", "ultimate"]) == [1, 1386]
  end

  test "normalize tolerates start.gg game/ prefixed slugs" do
    Games.normalize(%{"id" => 3, "name" => "Project M", "slug" => "game/project-m"})
    assert Games.by_slug("project-m")[:videogame_id] == 3
    assert Games.slug_for_id(3) == "project-m"
  end

  test "unknown slugs and ids return nil" do
    assert Games.by_slug("dota-2") == nil
    assert Games.by_id(999_999) == nil
    assert Games.ids_for_slugs(["nope"]) == []
  end

  test "sync loads the videogame list from start.gg and registers games" do
    FakeTransport.put(
      :query,
      "Videogames",
      Fixtures.games_response([
        Fixtures.videogame(1, "melee", "Super Smash Bros. Melee", "Melee"),
        Fixtures.videogame(1386, "ultimate", "Super Smash Bros. Ultimate", "Ultimate")
      ])
    )

    assert {:ok, count} = Games.sync()
    assert count >= 2
    assert Games.by_slug("ultimate")[:videogame_id] == 1386
  end

  test "sync errors propagate when upstream is unhappy" do
    FakeTransport.put(:query, "Videogames", %{error: :upstream_broke})
    assert {:error, :upstream_broke} = Games.sync()
  end
end
