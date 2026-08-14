defmodule KusaData.Tournament do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournaments" do
    field :startgg_id, :integer
    field :slug, :string

    has_many :events, KusaData.Event

    timestamps()
  end

  @doc false
  def changeset(tournament, attrs) do
    tournament
    |> cast(attrs, [:startgg_id, :slug])
    |> validate_required([:startgg_id, :slug])
    |> validate_number(:startgg_id, greater_than: 0)
    |> unique_constraint(:startgg_id)
    |> unique_constraint(:slug)
  end
end
