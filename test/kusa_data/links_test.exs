defmodule KusaData.LinksTest do
  use ExUnit.Case, async: true

  alias KusaData.Links

  test "parses a full start.gg tournament URL" do
    assert {:ok, %{tournament: "tournament/genesis-x", event: nil}} =
             Links.parse("https://www.start.gg/tournament/genesis-x")
  end

  test "parses a start.gg URL with an event" do
    assert {:ok,
            %{
              tournament: "tournament/genesis-x",
              event: "tournament/genesis-x/event/melee-singles"
            }} = Links.parse("https://www.start.gg/tournament/genesis-x/event/melee-singles")
  end

  test "parses a start.gg URL with trailing junk after the event" do
    assert {:ok,
            %{
              tournament: "tournament/genesis-x",
              event: "tournament/genesis-x/event/melee-singles"
            }} =
             Links.parse(
               "https://start.gg/tournament/genesis-x/event/melee-singles/brackets/12345"
             )
  end

  test "parses bare slugs with and without scheme" do
    assert {:ok, %{tournament: "tournament/foo"}} = Links.parse("tournament/foo")
    assert {:ok, %{event: "tournament/foo/event/bar"}} = Links.parse("tournament/foo/event/bar")
  end

  test "parses the legacy smash.gg host" do
    assert {:ok, %{tournament: "tournament/foo"}} = Links.parse("https://smash.gg/tournament/foo")
  end

  test "strips query strings and fragments" do
    assert {:ok, %{tournament: "tournament/foo"}} =
             Links.parse("https://www.start.gg/tournament/foo?tab=overview")
  end

  test "rejects non-start.gg URLs and junk" do
    assert :error = Links.parse("https://evil.example.com/tournament/foo")
    assert :error = Links.parse("")
    assert :error = Links.parse("hello world")
  end
end
