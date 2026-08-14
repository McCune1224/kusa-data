defmodule KusaData.CrawlState do
  use Ecto.Schema
  import Ecto.Changeset

  schema "crawl_state" do
    field :window_end, :integer
    field :seen_ids, {:array, :integer}, default: []

    belongs_to :game, KusaData.Game

    timestamps()
  end

  @doc false
  def changeset(crawl_state, attrs) do
    crawl_state
    |> cast(attrs, [:window_end, :seen_ids, :game_id])
    |> validate_required([:window_end, :game_id])
    |> validate_number(:window_end, greater_than: 0)
    |> unique_constraint(:game_id)
  end
end
