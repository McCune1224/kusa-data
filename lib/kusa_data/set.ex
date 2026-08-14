defmodule KusaData.Set do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sets" do
    field :startgg_id, :integer
    field :state, :integer
    field :completed_at, :utc_datetime
    field :winner_score, :integer
    field :loser_score, :integer

    belongs_to :event, KusaData.Event
    belongs_to :winner, KusaData.Player, foreign_key: :winner_player_id
    belongs_to :loser, KusaData.Player, foreign_key: :loser_player_id

    timestamps()
  end

  @doc false
  def changeset(set, attrs) do
    set
    |> cast(attrs, [
      :startgg_id,
      :state,
      :completed_at,
      :winner_score,
      :loser_score,
      :event_id,
      :winner_player_id,
      :loser_player_id
    ])
    |> validate_required([:startgg_id, :state, :event_id])
    |> validate_number(:startgg_id, greater_than: 0)
    |> unique_constraint(:startgg_id)
  end
end
