defmodule KusaData.Watches.Delivery.Discord do
  @moduledoc "Discord webhook adapter; disabled without an explicit webhook URL."

  def deliver(notification, _user, prefs) do
    config = Application.get_env(:kusa_data, :notification_discord, [])
    webhook = prefs["discord_webhook"] || Keyword.get(config, :webhook)

    if webhook do
      Req.post(webhook,
        json: %{
          content:
            "KusaData: watched #{notification.payload["kind"]} #{notification.payload["target_id"]} changed."
        },
        receive_timeout: 5_000
      )
      |> normalize_response()
    else
      {:error, :disabled}
    end
  end

  defp normalize_response({:ok, %{status: status}}) when status in 200..299, do: {:ok, :sent}
  defp normalize_response({:ok, %{status: status}}), do: {:error, {:http, status}}
  defp normalize_response({:error, reason}), do: {:error, reason}
end
