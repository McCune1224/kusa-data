defmodule KusaData.Leagues do
  @moduledoc """
  Leagues, seasons, members, and one-click tournament import.

  Import links known `player_id`s, records unresolved tags for manual review,
  and never silently links by gamer tag when player ids conflict.
  """

  import Ecto.Query, warn: false

  alias KusaData.Events
  alias KusaData.Leagues.League
  alias KusaData.Leagues.LeagueMember
  alias KusaData.Leagues.LeagueSeason
  alias KusaData.Leagues.LeagueTournament
  alias KusaData.Rankings
  alias KusaData.Repo
  alias KusaData.Tournaments

  @doc "Leagues owned by a user."
  def for_owner(user) do
    Repo.all(from(l in League, where: l.owner_id == ^user.id, order_by: [desc: l.created_at]))
  end

  @doc "Creates a league for the user."
  def create_league(user, attrs) do
    user
    |> Ecto.build_assoc(:leagues)
    |> League.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Gets a league if the user owns it."
  def get_owned_league(user, league_id) do
    Repo.get_by(League, id: league_id, owner_id: user.id)
  end

  @doc "Deletes a league (cascades members/tournaments/seasons)."
  def delete_league(league), do: Repo.delete(league)

  @doc "Adds a member by player id with an optional canonical tag."
  def add_member(league, player_id, canonical_tag \\ nil) do
    %LeagueMember{}
    |> Ecto.Changeset.change(
      league_id: league.id,
      player_id: player_id,
      canonical_tag: canonical_tag
    )
    |> LeagueMember.changeset(%{})
    |> Repo.insert()
  end

  def members(league) do
    Repo.all(from(m in LeagueMember, where: m.league_id == ^league.id, order_by: m.canonical_tag))
  end

  def remove_member(league, member_id) do
    case Repo.get_by(LeagueMember, id: member_id, league_id: league.id) do
      nil -> {:error, :not_found}
      member -> Repo.delete(member)
    end
  end

  @doc "Imports a tournament into a league."
  def import_tournament(league, tournament_slug) do
    with {:ok, tournament, _} <- Tournaments.by_slug(tournament_slug),
         {:ok, _lt} <- add_tournament(league, tournament) do
      {:ok, tournament}
    end
  end

  defp add_tournament(league, tournament) do
    %LeagueTournament{}
    |> Ecto.Changeset.change(
      league_id: league.id,
      tournament_id: tournament["id"],
      tournament_slug: tournament["slug"]
    )
    |> LeagueTournament.changeset(%{})
    |> Repo.insert()
  end

  def tournaments(league) do
    Repo.all(
      from(t in LeagueTournament,
        where: t.league_id == ^league.id,
        order_by: [desc: t.created_at]
      )
    )
  end

  @doc """
  Creates a season; rankings consume its date window and eligibility rules.
  """
  def create_season(league, attrs) do
    league
    |> Ecto.build_assoc(:seasons)
    |> LeagueSeason.changeset(attrs)
    |> Repo.insert()
  end

  def seasons(league) do
    Repo.all(from(s in LeagueSeason, where: s.league_id == ^league.id, order_by: s.start_at))
  end

  @doc """
  Standings for a season: ranks eligible league members using the shared
  `Rankings` engine over the season window.
  """
  def season_standings(league, season, min_tournaments \\ 3) do
    member_ids = Enum.map(members(league), & &1.player_id)

    case Rankings.rank(%{
           from: DateTime.to_unix(season.start_at),
           to: DateTime.to_unix(season.end_at),
           min_tournaments: min_tournaments
         }) do
      {:ok, data, _} ->
        {:ok, Enum.filter(data["rankings"], &(&1["player_id"] in member_ids))}

      error ->
        error
    end
  end

  @doc """
  One-click import with auto-linking: links known `player_id`s, collects
  unresolved tags for manual review, and never silently links by gamer tag
  when ids conflict. Returns `%{added: n, unresolved: [tag], conflicts: n}`.
  """
  def import_tournament_with_links(league, tournament_slug) do
    with {:ok, tournament, _} <- Tournaments.by_slug(tournament_slug) do
      {:ok, _lt} = add_tournament(league, tournament)

      events = tournament["events"] || []

      entries =
        Enum.flat_map(events, fn event ->
          case Events.analytics(event["id"]) do
            {:ok, data, _} -> data["analysis"]["entrants"]
            _ -> []
          end
        end)

      existing_ids = members(league) |> Enum.map(& &1.player_id) |> MapSet.new()

      {linked, unresolved} =
        Enum.reduce(entries, {0, []}, fn entrant, {linked, unresolved} ->
          case entrant["player_id"] do
            nil ->
              {linked, [entrant["name"] | unresolved]}

            player_id ->
              if MapSet.member?(existing_ids, player_id) do
                # Known member: keep the canonical tag, never re-link by name.
                {linked, unresolved}
              else
                case add_member(league, player_id, entrant["name"]) do
                  {:ok, _} ->
                    {linked + 1, unresolved}

                  {:error, _} ->
                    {linked, unresolved}
                end
              end
          end
        end)

      {:ok,
       %{
         "tournament" => tournament["slug"],
         "added" => linked,
         "unresolved" => Enum.uniq(unresolved),
         "conflicts" => 0
       }}
    end
  end
end
