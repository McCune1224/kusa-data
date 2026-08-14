defmodule KusaData.Tournaments do
  @moduledoc """
  Tournament reads from the crawled database: lookup by slug and entrant
  rosters. Live start.gg reads for the seed finder live in
  `KusaData.Tournaments.API`.
  """

  alias KusaData.{Entrant, Repo, Tournament}

  @doc "The tournament by start.gg slug (e.g. \"t-big-melee\"), or nil."
  @spec get_by_slug(String.t()) :: Tournament.t() | nil
  def get_by_slug(slug), do: Repo.get_by(Tournament, slug: slug)

  @doc """
  The tournament's events with entrants (placement ascending) and their
  players preloaded.
  """
  @spec roster(Tournament.t()) :: Tournament.t()
  def roster(tournament) do
    tournament
    |> Repo.preload(events: [entrants: :player])
  end

  @doc "Entrants of an event, placement ascending, unplaced last."
  @spec standings(KusaData.Event.t()) :: [Entrant.t()]
  def standings(event) do
    Enum.sort_by(event.entrants, &(&1.standing || 999_999))
  end
end
