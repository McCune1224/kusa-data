defmodule KusaData.Leagues.LeagueMember do
  @moduledoc "A player linked into a league, with a canonical tag."
  use Ecto.Schema

  import Ecto.Changeset

  schema "league_members" do
    field(:player_id, :integer)
    field(:canonical_tag, :string)
    belongs_to(:league, KusaData.Leagues.League)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:player_id, :canonical_tag])
    |> validate_required([:player_id])
    |> unique_constraint([:league_id, :player_id])
  end
end
