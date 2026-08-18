defmodule KusaData.Repo.Migrations.AddNotificationDelivery do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :dedup_key, :string
      add :delivery_status, :string, null: false, default: "pending"
      add :delivery_attempts, :integer, null: false, default: 0
      add :last_error, :text
    end

    create unique_index(:notifications, [:dedup_key])
  end
end
