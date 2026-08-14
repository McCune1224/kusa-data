defmodule KusaData.Tournaments.UrlTest do
  use ExUnit.Case, async: true

  alias KusaData.Tournaments.Url

  test "parses a canonical tournament URL" do
    assert Url.normalize("https://www.start.gg/tournament/genesis-x2/details") == %{
             tournament_slug: "genesis-x2",
             event_slug: nil,
             canonical: "https://www.start.gg/tournament/genesis-x2"
           }
  end

  test "accepts URLs without scheme and without www" do
    assert %{tournament_slug: "genesis-x2", event_slug: nil} =
             Url.normalize("start.gg/tournament/genesis-x2")
  end

  test "parses event URLs" do
    assert Url.normalize("https://start.gg/tournament/genesis-x2/event/melee-singles") == %{
             tournament_slug: "genesis-x2",
             event_slug: "melee-singles",
             canonical: "https://www.start.gg/tournament/genesis-x2/event/melee-singles"
           }
  end

  test "accepts the /events/ listing path" do
    assert %{tournament_slug: "genesis-x2", event_slug: nil} =
             Url.normalize("https://start.gg/tournament/genesis-x2/events")
  end

  test "rejects non-start.gg hosts" do
    assert Url.normalize("https://smash.gg/tournament/x") == nil
    assert Url.normalize("https://example.com/tournament/x") == nil
  end

  test "rejects malformed paths" do
    assert Url.normalize("https://start.gg/tournament") == nil
    assert Url.normalize("https://start.gg/tournament/x/unknown-segment") == nil
    assert Url.normalize("https://start.gg/tournament/x/event") == nil
    assert Url.normalize("") == nil
    assert Url.normalize("   ") == nil
    assert Url.normalize("not a url") == nil
  end
end
