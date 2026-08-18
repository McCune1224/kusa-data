defmodule KusaData.Watches.Delivery do
  @moduledoc "Dispatches persisted notifications through explicitly configured channels."

  alias KusaData.Watches.Delivery.Discord
  alias KusaData.Watches.Delivery.Email
  alias KusaData.Watches.Delivery.Telegram

  @adapters %{email: Email, telegram: Telegram, discord: Discord}

  @doc "Delivers a notification to the user's configured channels."
  def deliver(notification, user, prefs \\ %{}) do
    channels =
      prefs
      |> Map.get("channels", [])
      |> Enum.map(&normalize_channel/1)
      |> Enum.filter(&Map.has_key?(@adapters, &1))

    if channels == [] do
      {:ok, :disabled}
    else
      results =
        Enum.map(channels, fn channel ->
          {@adapters[channel], apply(@adapters[channel], :deliver, [notification, user, prefs])}
        end)

      if Enum.any?(results, fn {_adapter, result} -> match?({:ok, _}, result) end) do
        {:ok, results}
      else
        {:error, results}
      end
    end
  end

  defp normalize_channel("email"), do: :email
  defp normalize_channel("telegram"), do: :telegram
  defp normalize_channel("discord"), do: :discord
  defp normalize_channel(channel) when is_atom(channel), do: channel
  defp normalize_channel(_), do: nil
end
