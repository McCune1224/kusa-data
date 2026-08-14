defmodule KusaDataWeb.PageController do
  use KusaDataWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
