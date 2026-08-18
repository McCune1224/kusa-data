defmodule KusaData.Watches.Delivery.Email do
  @moduledoc "Swoosh email adapter, disabled unless SMTP configuration is explicit."

  import Swoosh.Email

  def deliver(notification, user, _prefs) do
    config = Application.get_env(:kusa_data, :notification_email, [])

    if Keyword.get(config, :smtp_host) && user.email do
      email =
        new()
        |> to(user.email)
        |> from(Keyword.fetch!(config, :from))
        |> subject("KusaData: a watched #{notification.payload["kind"]} changed")
        |> text_body(body(notification))

      adapter_config = [
        relay: config[:smtp_host],
        username: config[:smtp_username],
        password: config[:smtp_password],
        port: config[:smtp_port] || 587
      ]

      Swoosh.Adapters.SMTP.deliver(email, adapter_config)
    else
      {:error, :disabled}
    end
  end

  defp body(notification) do
    "A watched #{notification.payload["kind"]} changed: #{notification.payload["target_id"]}.\n\nOpen KusaData to inspect the current result."
  end
end
