defmodule KusaData.Rating do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ratings" do
    field :elo, :float
    field :sets, :integer
    field :wins, :integer
    field :losses, :integer

    belongs_to :game, KusaData.Game
    belongs_to :player, KusaData.Player

    timestamps()
  end

  @doc false
  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:elo, :sets, :wins, :losses, :game_id, :player_id])
    |> validate_required([:elo, :sets, :wins, :losses, :game_id, :player_id])
    |> validate_number(:sets, greater_than_or_equal_to: 0)
    |> validate_number(:wins, greater_than_or_equal_to: 0)
    |> validate_number(:losses, greater_than_or_equal_to: 0)
    |> unique_constraint([:game_id, :player_id])
  end
end
