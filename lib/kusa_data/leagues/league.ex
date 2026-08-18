defmodule KusaData.Leagues.League do
  @moduledoc "A user-owned league grouping tournaments into seasons."
  use Ecto.Schema

  import Ecto.Changeset

  alias KusaData.Accounts.User

  schema "leagues" do
    field(:name, :string)
    belongs_to(:owner, User, foreign_key: :owner_id)

    has_many(:members, KusaData.Leagues.LeagueMember)
    has_many(:tournaments, KusaData.Leagues.LeagueTournament)
    has_many(:seasons, KusaData.Leagues.LeagueSeason)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(league, attrs) do
    league
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 80)
  end
end
