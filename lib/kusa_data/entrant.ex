defmodule KusaData.Entrant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "entrants" do
    field :startgg_id, :integer
    field :standing, :integer

    belongs_to :event, KusaData.Event
    belongs_to :player, KusaData.Player

    timestamps()
  end

  @doc false
  def changeset(entrant, attrs) do
    entrant
    |> cast(attrs, [:startgg_id, :standing, :event_id, :player_id])
    |> validate_required([:startgg_id, :event_id])
    |> validate_number(:startgg_id, greater_than: 0)
    |> unique_constraint(:startgg_id)
  end
end
