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

  test "handles query strings and fragments together on event URLs" do
    assert {:ok,
            %{
              tournament: "tournament/genesis-x",
              event: "tournament/genesis-x/event/melee-singles"
            }} =
             Links.parse(
               "https://www.start.gg/tournament/genesis-x/event/melee-singles?tab=brackets&phase=2#top-8"
             )

    assert {:ok, %{tournament: "tournament/foo"}} =
             Links.parse("start.gg/tournament/foo?utm_source=share#fragment")
  end

  test "rejects non-tournament paths on supported hosts" do
    assert :error = Links.parse("https://www.start.gg/user/mango")
    assert :error = Links.parse("https://start.gg/tournament")
    assert :error = Links.parse("https://start.gg/rankings/melee")
    assert :error = Links.parse("https://start.gg/")
  end

  test "rejects malformed and lookalike hosts" do
    assert :error = Links.parse("https://start.gg.evil.com/tournament/foo")
    assert :error = Links.parse("https://evil-start.gg/tournament/foo")
    assert :error = Links.parse("start.ggx/tournament/foo")
    assert :error = Links.parse("https://sub.start.gg/tournament/foo")
    assert :error = Links.parse("ftp://start.gg/tournament/foo")
  end

  test "rejects non-start.gg URLs and junk" do
    assert :error = Links.parse("https://evil.example.com/tournament/foo")
    assert :error = Links.parse("")
    assert :error = Links.parse("hello world")
    assert :error = Links.parse("tournament")
    assert :error = Links.parse("tournament/")
  end
end
