defmodule KusaData.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :startgg_id, :integer
    field :name, :string

    belongs_to :tournament, KusaData.Tournament
    belongs_to :game, KusaData.Game

    has_many :sets, KusaData.Set
    has_many :entrants, KusaData.Entrant

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:startgg_id, :name, :tournament_id, :game_id])
    |> validate_required([:startgg_id, :name, :tournament_id, :game_id])
    |> validate_number(:startgg_id, greater_than: 0)
    |> unique_constraint(:startgg_id)
  end
end
