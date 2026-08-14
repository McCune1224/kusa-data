defmodule KusaData.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :key, :string
    field :name, :string
    field :videogame_id, :integer

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:key, :name, :videogame_id])
    |> validate_required([:key, :name, :videogame_id])
    |> validate_number(:videogame_id, greater_than: 0)
    |> unique_constraint(:key)
    |> unique_constraint(:videogame_id)
  end
end
