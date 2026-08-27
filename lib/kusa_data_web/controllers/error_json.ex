defmodule KusaDataWeb.ErrorJSON do
  def render("404.json", _assigns), do: %{errors: %{detail: "Not Found"}}
  def render("500.json", _assigns), do: %{errors: %{detail: "Internal Server Error"}}
  def render(_template, _assigns), do: %{errors: %{detail: "Error"}}
end
