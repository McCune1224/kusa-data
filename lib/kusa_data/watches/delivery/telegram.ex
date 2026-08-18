defmodule KusaData.Watches.Delivery.Telegram do
  @moduledoc "Telegram Bot API adapter; disabled without an explicit webhook token/chat."

  def deliver(notification, _user, prefs) do
    config = Application.get_env(:kusa_data, :notification_telegram, [])
    token = prefs["telegram_token"] || Keyword.get(config, :token)
    chat_id = prefs["telegram_chat_id"] || Keyword.get(config, :chat_id)

    if token && chat_id do
      Req.post("https://api.telegram.org/bot#{token}/sendMessage",
        json: %{chat_id: chat_id, text: message(notification)},
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

  defp message(notification),
    do:
      "KusaData: watched #{notification.payload["kind"]} #{notification.payload["target_id"]} changed."
end
