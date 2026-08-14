defmodule KusaData.Tournaments.APITest do
  use ExUnit.Case, async: false

  alias KusaData.{Cache, Tournaments}

  setup do
    Application.put_env(:kusa_data, Cache, command: fn _commands -> {:error, :down} end)
    on_exit(fn -> Application.delete_env(:kusa_data, Cache) end)
    :ok
  end

  defp with_fetch(fun) do
    Application.put_env(:kusa_data, Tournaments.API, fetch: fun)
    on_exit(fn -> Application.delete_env(:kusa_data, Tournaments.API) end)
  end

  test "events/2 normalizes the payload and sorts nothing (API order kept)" do
    with_fetch(fn _query, variables ->
      assert variables == %{slug: "tournament/genesis-x2", videogameIds: [1]}

      {:ok,
       %{
         "tournament" => %{
           "id" => 7,
           "name" => "GENESIS X2",
           "events" => [
             %{
               "id" => 100,
               "name" => "Melee Singles",
               "slug" => "tournament/genesis-x2/event/melee-singles"
             }
           ]
         }
       }}
    end)

    assert {:ok, %{id: 7, name: "GENESIS X2", events: [%{id: 100, name: "Melee Singles"}]}} =
             Tournaments.API.events("tournament/genesis-x2", 1)
  end

  test "events/2 returns :tournament_not_found for a null tournament" do
    with_fetch(fn _query, _variables -> {:ok, %{"tournament" => nil}} end)
    assert {:error, :tournament_not_found} = Tournaments.API.events("tournament/nope", 1)
  end

  test "seeding/1 normalizes and sorts entrants by lowest seed" do
    with_fetch(fn _query, variables ->
      assert variables == %{eventId: 100}

      {:ok,
       %{
         "event" => %{
           "id" => 100,
           "name" => "Melee Singles",
           "entrants" => %{
             "nodes" => [
               %{"id" => 1, "name" => "Unseeded", "seeds" => []},
               %{"id" => 2, "name" => "Second", "seeds" => [%{"seedNum" => 2}]},
               %{"id" => 3, "name" => "First", "seeds" => [%{"seedNum" => 1}, %{"seedNum" => 1}]}
             ]
           }
         }
       }}
    end)

    assert {:ok, %{id: 100, entrants: entrants}} = Tournaments.API.seeding(100)

    assert Enum.map(entrants, & &1.name) == ["First", "Second", "Unseeded"]
    assert hd(entrants).seed_nums == [1, 1]
  end

  test "seeding/1 returns :event_not_found for a null event" do
    with_fetch(fn _query, _variables -> {:ok, %{"event" => nil}} end)
    assert {:error, :event_not_found} = Tournaments.API.seeding(1)
  end
end
