defmodule KusaData.Leagues.LeagueTournament do
  @moduledoc "A tournament imported into a league."
  use Ecto.Schema

  import Ecto.Changeset

  schema "league_tournaments" do
    field(:tournament_id, :integer)
    field(:tournament_slug, :string)
    belongs_to(:league, KusaData.Leagues.League)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(lt, attrs) do
    lt
    |> cast(attrs, [:tournament_id, :tournament_slug])
    |> validate_required([:tournament_id, :tournament_slug])
    |> unique_constraint([:league_id, :tournament_id])
  end
end
