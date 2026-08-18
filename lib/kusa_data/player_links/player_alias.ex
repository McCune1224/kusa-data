defmodule KusaData.PlayerLinks.PlayerAlias do
  @moduledoc """
  A gamer-tag alias a user associates with a start.gg player id, so one tag
  has a single canonical profile across tournaments.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "player_aliases" do
    field(:player_id, :integer)
    field(:alias, :string)
    belongs_to(:user, KusaData.Accounts.User)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(alias_row, attrs) do
    alias_row
    |> cast(attrs, [:player_id, :alias])
    |> validate_required([:player_id, :alias])
    |> validate_length(:alias, min: 1, max: 80)
    |> unique_constraint(:alias, name: :player_aliases_user_id_alias_index)
  end
end
