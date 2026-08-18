defmodule KusaData.Bookmarks.Bookmark do
  @moduledoc """
  A saved tournament. `tournament_slug` is the canonical start.gg slug;
  `tournament_snapshot` stores the last fetched display data so "your
  tournaments" still renders when start.gg is unavailable.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "bookmarks" do
    field(:tournament_slug, :string)
    field(:tournament_snapshot, :map, default: %{})
    belongs_to(:user, KusaData.Accounts.User)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:tournament_slug, :tournament_snapshot])
    |> validate_required([:tournament_slug])
    |> unique_constraint([:user_id, :tournament_slug])
  end
end
