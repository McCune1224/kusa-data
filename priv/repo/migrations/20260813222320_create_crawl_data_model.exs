defmodule KusaData.Repo.Migrations.CreateCrawlDataModel do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :key, :string, null: false
      add :name, :string, null: false
      add :videogame_id, :integer, null: false

      timestamps()
    end

    create unique_index(:games, [:key])
    create unique_index(:games, [:videogame_id])

    create table(:players) do
      add :user_id, :integer
      add :player_id, :integer
      add :gamer_tag, :string, null: false
      add :prefix, :string

      timestamps()
    end

    create index(:players, [:user_id])
    create index(:players, [:gamer_tag])

    create table(:tournaments) do
      add :startgg_id, :integer, null: false
      add :slug, :string, null: false

      timestamps()
    end

    create unique_index(:tournaments, [:startgg_id])
    create unique_index(:tournaments, [:slug])

    create table(:events) do
      add :startgg_id, :integer, null: false
      add :name, :string, null: false
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:events, [:startgg_id])

    create table(:sets) do
      add :startgg_id, :integer, null: false
      add :state, :integer, null: false
      add :completed_at, :utc_datetime
      add :winner_player_id, references(:players, on_delete: :nilify_all)
      add :loser_player_id, references(:players, on_delete: :nilify_all)
      add :winner_score, :integer
      add :loser_score, :integer
      add :event_id, references(:events, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sets, [:startgg_id])
    create index(:sets, [:event_id])

    create table(:entrants) do
      add :startgg_id, :integer, null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :delete_all)
      add :standing, :integer

      timestamps()
    end

    create unique_index(:entrants, [:startgg_id])

    create table(:ratings) do
      add :elo, :float, null: false
      add :sets, :integer, null: false, default: 0
      add :wins, :integer, null: false, default: 0
      add :losses, :integer, null: false, default: 0
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:ratings, [:game_id, :player_id])

    create table(:crawl_state) do
      add :window_end, :integer, null: false
      add :seen_ids, {:array, :integer}, default: [], null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:crawl_state, [:game_id])
  end
end
