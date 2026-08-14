defmodule KusaData.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :user_id, :integer
    field :player_id, :integer
    field :gamer_tag, :string
    field :prefix, :string

    has_many :sets_won, KusaData.Set, foreign_key: :winner_player_id
    has_many :sets_lost, KusaData.Set, foreign_key: :loser_player_id
    has_many :ratings, KusaData.Rating

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:user_id, :player_id, :gamer_tag, :prefix])
    |> validate_required([:gamer_tag])
    |> validate_number(:user_id, greater_than: 0)
    |> validate_number(:player_id, greater_than: 0)
  end
end
