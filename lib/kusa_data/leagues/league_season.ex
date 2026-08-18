defmodule KusaData.Leagues.LeagueSeason do
  @moduledoc "A dated season within a league; rankings consume its window."
  use Ecto.Schema

  import Ecto.Changeset

  schema "league_seasons" do
    field(:name, :string)
    field(:start_at, :utc_datetime_usec)
    field(:end_at, :utc_datetime_usec)
    belongs_to(:league, KusaData.Leagues.League)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(season, attrs) do
    changeset =
      season
      |> cast(attrs, [:name, :start_at, :end_at])
      |> validate_required([:name, :start_at, :end_at])

    validate_change(changeset, :end_at, fn :end_at, end_at ->
      start_at = get_field(changeset, :start_at)

      if start_at && DateTime.compare(end_at, start_at) != :gt do
        [end_at: "must be after the season start"]
      else
        []
      end
    end)
  end
end
