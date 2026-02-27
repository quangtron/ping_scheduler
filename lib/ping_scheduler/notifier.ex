defmodule PingScheduler.Notifier do
  def notify(status, detail, config) do
    telegram = Map.get(config, "telegram", %{})
    bot_token = get_telegram_token(telegram)
    chat_id = Map.get(telegram, "chat_id", "")

    if valid_config?(bot_token, chat_id) do
      message = format_message(status, detail)
      send_telegram(bot_token, chat_id, message)
    else
      {:error, "Telegram not configured"}
    end
  end

  defp get_telegram_token(telegram) do
    Map.get(telegram, "bot_token", "") || System.get_env("TELEGRAM_BOT_TOKEN")
  end

  defp valid_config?(bot_token, chat_id) do
    bot_token != nil and bot_token != "" and chat_id != nil and chat_id != ""
  end

  defp format_message(status, detail) do
    emoji = if status == "SUCCESS", do: "✅", else: "❌"
    detail_str = if detail == :retried_success, do: "retried -> SUCCESS", else: "#{detail}"

    """
    *Ping Scheduler*
    #{emoji} *Status:* #{status}
    📝 *Detail:* #{detail_str}
    """
  end

  defp send_telegram(bot_token, chat_id, message) do
    url = "https://api.telegram.org/bot#{bot_token}/sendMessage"

    body = %{
      chat_id: chat_id,
      text: message,
      parse_mode: "Markdown"
    }

    case Req.post(url, json: body) |> IO.inspect() do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Telegram API returned status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to send Telegram notification: #{inspect(reason)}"}
    end
  end
end
