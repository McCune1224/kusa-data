defmodule KusaData.Brackets do
  @moduledoc """
  Bracket structure for an event: phases, pools (phase groups), and
  round-by-round sets with prerequisite links.

  The built payload drives the bracket tab. start.gg round numbers are
  positive for the winners side and negative for the losers side (counting
  down toward grand finals); columns keep that ordering so winners rounds
  read left-to-right and losers rounds run below them.

  All ids are normalized to strings (`set_id`, `winner_id`, `entrant_id`,
  group ids) so UI focus/path logic never mixes int and string keys.
  Pure helpers `build/2` and `run_for/2` are public for testing.
  """

  alias KusaData.Cache
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries

  @per_page 250
  @max_pages 10

  @type bracket :: %{
          required(String.t()) => term()
        }

  @doc """
  Bracket payload for one event:

      %{"phases" => [%{"id", "name", "groups" => [...]}],
       "groups" => [%{"id", "label", "phase", "set_count",
                      "winners_rounds" => [%{"round", "name", "sets"}],
                      "losers_rounds" => [...]}]}

  Groups without a matching phase entry (and sets with no phase group at all)
  are collected into fallback groups so nothing is silently dropped. Cached
  briefly while brackets run; invalidated by `clear_cache/1`.
  """
  @spec for_event(integer()) :: {:ok, bracket(), :hit | :miss | :bypass} | {:error, term()}
  def for_event(event_id) do
    Cache.fetch("brackets:#{event_id}", 2 * 60, fn ->
      with {:ok, phases_data} <- Client.query(Queries.event_phases(event_id)),
           {:ok, raw_sets} <- bracket_sets(event_id) do
        phases = map_phases(phases_data)
        {:ok, build(phases, Enum.map(raw_sets, &map_set/1))}
      end
    end)
  end

  @doc "Drops the cached bracket payload so the next fetch is fresh."
  @spec clear_cache(integer()) :: :ok
  def clear_cache(event_id), do: Cache.delete("brackets:#{event_id}")

  @doc """
  Assembles phases and mapped sets into the bracket payload. Sets whose phase
  group is missing from the phase list land in a fallback group ("Bracket"
  when they have no group identity at all).
  """
  @spec build([map()], [map()]) :: bracket()
  def build(phases, sets) do
    sets_by_group = Enum.group_by(sets, &(&1["group_id"] || ""))

    declared =
      Enum.flat_map(phases, fn phase ->
        Enum.map(phase["groups"] || [], fn group ->
          %{
            "id" => to_string(group["id"]),
            "label" => group_label(group["displayIdentifier"], phase),
            "phase" => phase["name"]
          }
        end)
      end)

    used_ids = MapSet.new(declared, & &1["id"])

    extras =
      sets_by_group
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(used_ids, &1))
      |> Enum.sort()
      |> Enum.map(fn group_id ->
        first_set = hd(Map.get(sets_by_group, group_id))

        %{
          "id" => group_id,
          "label" => group_label(first_set["group_label"], %{"name" => nil}),
          "phase" => first_set["phase_name"]
        }
      end)

    groups =
      Enum.map(declared ++ extras, fn group ->
        Map.merge(group, group_view(Map.get(sets_by_group, group["id"], [])))
      end)
      |> Enum.reject(&(&1["set_count"] == 0 and &1["id"] != ""))

    %{"phases" => phases, "groups" => groups}
  end

  @doc """
  One entrant's run through a single group, in play order (completion time,
  then set id):

      %{"sets" => [%{"set_id", "result" => "W" | "L", "opponent",
                     "score", "round_name"}],
       "eliminator" => name | nil}
  """
  @spec run_for([map()], String.t()) :: map()
  def run_for(group_sets, entrant_id) do
    mine =
      group_sets
      |> Enum.filter(fn set ->
        Enum.any?(set["slots"] || [], &(&1["entrant_id"] == entrant_id))
      end)
      |> Enum.sort_by(&{&1["completed_at"] || 0, int_id(&1["id"])})

    entries =
      Enum.map(mine, fn set ->
        opponent =
          Enum.find_value(set["slots"] || [], fn slot ->
            if slot["entrant_id"] != entrant_id, do: slot["name"], else: nil
          end)

        %{
          "set_id" => set["id"],
          "result" => if(set["winner_id"] == entrant_id, do: "W", else: "L"),
          "opponent" => opponent,
          "score" => set["score"],
          "round_name" => set["round_name"]
        }
      end)

    eliminator =
      entries
      |> Enum.filter(&(&1["result"] == "L"))
      |> List.last()
      |> case do
        nil -> nil
        loss -> loss["opponent"]
      end

    %{"sets" => entries, "eliminator" => eliminator}
  end

  defp map_phases(phases_data) do
    get_in(phases_data, ["event", "phases"])
    |> List.wrap()
    |> Enum.map(fn phase ->
      groups =
        get_in(phase, ["phaseGroups", "nodes"])
        |> List.wrap()
        |> Enum.map(fn group ->
          %{"id" => group["id"], "displayIdentifier" => group["displayIdentifier"]}
        end)

      %{"id" => phase["id"], "name" => phase["name"], "groups" => groups}
    end)
  end

  defp bracket_sets(event_id) do
    with {:ok, first} <- Client.query(Queries.event_bracket_sets(event_id, 1, @per_page)) do
      case first["event"] do
        nil ->
          {:error, :not_found}

        event ->
          info = get_in(event, ["sets", "pageInfo"]) || %{}
          total_pages = min(info["totalPages"] || 1, @max_pages)
          pages = [first | remaining_pages(event_id, total_pages)]

          sets =
            pages
            |> Enum.flat_map(&(get_in(&1, ["event", "sets", "nodes"]) || []))
            |> Enum.reject(&is_nil/1)

          {:ok, sets}
      end
    end
  end

  defp remaining_pages(_event_id, total) when total <= 1, do: []

  defp remaining_pages(event_id, total_pages) do
    2..total_pages
    |> Task.async_stream(
      fn page -> Client.query(Queries.event_bracket_sets(event_id, page, @per_page)) end,
      max_concurrency: 5,
      timeout: :infinity,
      ordered: true
    )
    |> Enum.flat_map(fn
      {:ok, {:ok, data}} -> [data]
      _ -> []
    end)
  end

  @doc "Maps a raw `EventBracketSets` node to the normalized set shape used here."
  def map_set(node) do
    phase_group = node["phaseGroup"] || %{}
    phase = phase_group["phase"] || %{}

    %{
      "id" => to_string(node["id"]),
      "state" => node["state"],
      "winner_id" => node["winnerId"] && to_string(node["winnerId"]),
      "score" => node["displayScore"],
      "round" => node["round"],
      "round_name" => node["fullRoundText"],
      "completed_at" => node["completedAt"],
      "group_id" => phase_group["id"] && to_string(phase_group["id"]),
      "group_label" => phase_group["displayIdentifier"],
      "phase_name" => phase["name"],
      "slots" =>
        Enum.map(node["slots"] || [], fn slot ->
          entrant = slot["entrant"] || %{}

          %{
            "entrant_id" => entrant["id"] && to_string(entrant["id"]),
            "name" => entrant["name"],
            "prereq_id" => slot["prereqId"]
          }
        end)
    }
  end

  defp group_view([]) do
    %{"set_count" => 0, "winners_rounds" => [], "losers_rounds" => []}
  end

  defp group_view(sets) do
    by_round = Enum.group_by(sets, &(&1["round"] || 0))

    %{
      "set_count" => length(sets),
      "winners_rounds" =>
        by_round |> Map.keys() |> Enum.filter(&(&1 >= 0)) |> Enum.sort() |> round_views(by_round),
      "losers_rounds" =>
        by_round
        |> Map.keys()
        |> Enum.filter(&(&1 < 0))
        |> Enum.sort(:desc)
        |> round_views(by_round)
    }
  end

  defp round_views(rounds, by_round) do
    Enum.map(rounds, fn round ->
      sets = Map.fetch!(by_round, round)
      name = Enum.find_value(sets, & &1["round_name"]) || round_name(round)

      %{"round" => round, "name" => name, "sets" => Enum.sort_by(sets, &int_id(&1["id"]))}
    end)
  end

  defp round_name(round) when round >= 0, do: "Winners R#{round}"
  defp round_name(round), do: "Losers R#{abs(round)}"

  defp group_label(nil, phase), do: phase["name"] || "Bracket"
  defp group_label(label, _phase), do: label

  defp int_id(id) when is_integer(id), do: id

  defp int_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {number, ""} -> number
      _ -> 0
    end
  end

  defp int_id(_), do: 0
end
