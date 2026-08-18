defmodule KusaData.Watches.Watch do
  @moduledoc "A durable user-owned tournament, event, or player watch."

  use Ecto.Schema

  import Ecto.Changeset

  alias KusaData.Accounts.User

  schema "watches" do
    field(:kind, :string)
    field(:target_id, :string)
    field(:prefs, :map, default: %{})
    field(:snapshot, :map)
    field(:last_checked_at, :utc_datetime_usec)

    belongs_to(:user, User)
    has_many(:notifications, KusaData.Watches.Notification)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: :updated_at)
  end

  def changeset(watch, attrs) do
    watch
    |> cast(attrs, [:kind, :target_id, :prefs, :snapshot, :last_checked_at, :user_id])
    |> validate_required([:kind, :target_id, :user_id])
    |> validate_inclusion(:kind, ~w(tournament event player))
    |> unique_constraint([:user_id, :kind, :target_id])
  end
end
