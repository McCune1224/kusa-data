defmodule KusaDataWeb.API.EventController do
  use KusaDataWeb, :controller

  alias KusaData.Events

  def seeds(conn, %{"event" => event_id}) do
    case Events.seeding(event_id) do
      {:ok, data, _} -> json(conn, data)
      {:error, _} -> json(conn, %{error: "not_found"}) |> put_status(:not_found)
    end
  end

  def results(conn, %{"event" => event_id}) do
    case Events.results(event_id) do
      {:ok, data, _} -> json(conn, data)
      {:error, _} -> json(conn, %{error: "not_found"}) |> put_status(:not_found)
    end
  end

  def sets(conn, %{"event" => event_id}) do
    case Events.sets(event_id) do
      {:ok, data, _} -> json(conn, data)
      {:error, _} -> json(conn, %{error: "not_found"}) |> put_status(:not_found)
    end
  end

  def analytics(conn, %{"event" => event_id}) do
    case Events.analytics(event_id) do
      {:ok, data, _} -> json(conn, data)
      {:error, _} -> json(conn, %{error: "not_found"}) |> put_status(:not_found)
    end
  end
end
