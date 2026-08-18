defmodule KusaData.Bookmarks do
  @moduledoc """
  Bookmark/unbookmark tournaments. Idempotent: repeated bookmarks never
  create duplicates (unique `(user_id, tournament_slug)` constraint backs the
  application check). Requires an authenticated user.
  """

  import Ecto.Query, warn: false

  alias KusaData.Bookmarks.Bookmark
  alias KusaData.Repo

  @doc "Books a tournament for a user. Idempotent — returns the existing row on repeat."
  def bookmark(user, tournament_slug, snapshot \\ %{}) do
    case Repo.get_by(Bookmark, user_id: user.id, tournament_slug: tournament_slug) do
      nil ->
        %Bookmark{}
        |> Ecto.Changeset.change(
          user_id: user.id,
          tournament_slug: tournament_slug,
          tournament_snapshot: snapshot
        )
        |> Repo.insert()

      bookmark ->
        {:ok, bookmark}
    end
  end

  @doc "Removes a bookmark; returns `:ok` whether or not it existed."
  def unbookmark(user, tournament_slug) do
    case Repo.get_by(Bookmark, user_id: user.id, tournament_slug: tournament_slug) do
      nil ->
        :ok

      bookmark ->
        Repo.delete(bookmark)
        :ok
    end
  end

  @doc "All bookmarks for a user, newest first."
  def for_user(user, preload_slug \\ nil) do
    query =
      from(b in Bookmark,
        where: b.user_id == ^user.id,
        order_by: [desc: b.created_at]
      )

    query =
      if preload_slug do
        from(b in query, where: b.tournament_slug == ^preload_slug)
      else
        query
      end

    Repo.all(query)
  end

  @doc "Whether the user has the tournament bookmarked."
  def bookmarked?(user, tournament_slug) do
    Repo.exists?(
      from(b in Bookmark, where: b.user_id == ^user.id and b.tournament_slug == ^tournament_slug)
    )
  end
end
