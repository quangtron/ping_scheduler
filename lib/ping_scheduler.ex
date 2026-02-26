defmodule PingScheduler do
  @moduledoc """
  Claude Pro Ping Scheduler - sends ping to Anthropic API at scheduled times.
  """

  def run do
    IO.puts("Claude Pro Ping Scheduler starting...")

    case PingScheduler.Config.load() do
      {:ok, config} ->
        api_key = PingScheduler.Config.api_key(config)

        if is_nil(api_key) or api_key == "" do
          IO.puts(
            "ERROR: No API key found. Set ANTHROPIC_API_KEY environment variable or api_key in config.yaml"
          )

          System.halt(1)
        end

        ping_config = PingScheduler.Config.ping_config(config)
        schedules = PingScheduler.Config.schedules(config)

        IO.puts("Loaded #{length(schedules)} schedule(s)")

        schedule_name = get_schedule_name()
        result = PingScheduler.Pinger.ping(api_key, ping_config)

        log_result(schedule_name, result)
        IO.puts("Done.")

      {:error, reason} ->
        IO.puts("ERROR: #{reason}")
        System.halt(1)
    end
  end

  defp get_schedule_name do
    case System.get_env("SCHEDULE_NAME") do
      nil -> "Manual"
      name -> name
    end
  end

  defp log_result(schedule_name, {:ok, status, duration}) do
    log_entry = format_log(schedule_name, "SUCCESS", status, duration)
    write_log(log_entry)
    IO.puts(log_entry)
  end

  defp log_result(schedule_name, {:error, _reason, duration}) do
    log_entry = format_log(schedule_name, "FAILED", :failed, duration)
    write_log(log_entry)
    IO.puts(log_entry)
  end

  defp format_log(schedule_name, status, detail, duration) do
    timestamp = format_timestamp()
    detail_str = if detail == :retried_success, do: "retried -> SUCCESS", else: detail
    "#{timestamp} | #{schedule_name} | #{status} | #{detail_str} | #{duration}ms"
  end

  defp format_timestamp do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    :io.format("~4..0-~2..0-~2..0 ~2..0:~2..0:~2..0", [year, month, day, hour, minute, second])
  end

  defp write_log(entry) do
    log_file = Path.expand("ping.log", Path.dirname(__DIR__))

    case File.open(log_file, [:append, :utf8]) do
      {:ok, file} ->
        IO.write(file, entry <> "\n")
        File.close(file)

      {:error, reason} ->
        IO.puts("Warning: Could not write to log file: #{reason}")
    end
  end
end
