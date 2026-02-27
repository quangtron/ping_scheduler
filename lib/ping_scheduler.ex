defmodule PingScheduler do
  @moduledoc """
  Claude Pro Ping Scheduler - sends ping to Anthropic API at scheduled times.
  """

  def run do
    case PingScheduler.Config.load() do
      {:ok, config} ->
        api_key = PingScheduler.Config.api_key(config)

        if is_nil(api_key) or api_key == "" do
          System.halt(1)
        end

        ping_config = PingScheduler.Config.ping_config(config)
        result = PingScheduler.Pinger.ping(api_key, ping_config)

        send_noti(result, config)

      {:error, _reason} ->
        System.halt(1)
    end
  end

  defp send_noti({:ok, detail}, config) do
    PingScheduler.Notifier.notify("SUCCESS", detail, config)
  end

  defp send_noti({:error, reason}, config) do
    PingScheduler.Notifier.notify("FAILED", reason, config)
  end
end
