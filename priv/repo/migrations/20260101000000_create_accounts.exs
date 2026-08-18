defmodule KusaData.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :linked_player_id, :integer
      add :reset_token_hash, :string
      add :reset_sent_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])

    create table(:user_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create unique_index(:user_sessions, [:token])
    create index(:user_sessions, [:user_id])

    create table(:bookmarks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tournament_slug, :string, null: false
      add :tournament_snapshot, :map, default: %{}
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:bookmarks, [:user_id, :tournament_slug])

    create table(:watches) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :target_id, :string, null: false
      add :prefs, :map, default: %{}
      add :snapshot, :map
      add :last_checked_at, :utc_datetime_usec
      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:watches, [:user_id, :kind, :target_id])

    create table(:player_aliases) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :player_id, :integer, null: false
      add :alias, :string, null: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:player_aliases, [:user_id, :alias])
    create index(:player_aliases, [:user_id, :player_id])

    create table(:leagues) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create index(:leagues, [:owner_id])

    create table(:league_members) do
      add :league_id, references(:leagues, on_delete: :delete_all), null: false
      add :player_id, :integer, null: false
      add :canonical_tag, :string
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:league_members, [:league_id, :player_id])

    create table(:league_tournaments) do
      add :league_id, references(:leagues, on_delete: :delete_all), null: false
      add :tournament_id, :integer, null: false
      add :tournament_slug, :string, null: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:league_tournaments, [:league_id, :tournament_id])

    create table(:league_seasons) do
      add :league_id, references(:leagues, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :start_at, :utc_datetime_usec, null: false
      add :end_at, :utc_datetime_usec, null: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create index(:league_seasons, [:league_id])

    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :watch_id, references(:watches, on_delete: :delete_all)
      add :type, :string, null: false
      add :payload, :map, default: %{}
      add :read_at, :utc_datetime_usec
      add :delivered_at, :utc_datetime_usec
      add :created_at, :utc_datetime_usec, null: false
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:watch_id])
  end
end
