defmodule PingScheduler.Config do
  @config_file "config/config.yaml"

  def load do
    config_path = Path.expand(@config_file, File.cwd!())

    case YamlElixir.read_from_file(config_path) do
      {:ok, config} ->
        api_key = get_config(config, "api_key", System.get_env("ANTHROPIC_API_KEY"))
        bot_token = get_config(config, ["telegram", "bot_token"], System.get_env("BOT_TOKEN"))
        chat_id = get_config(config, ["telegram", "chat_id"], System.get_env("CHAT_ID"))

        {:ok,
         Map.merge(config, %{
           "api_key" => api_key,
           "telegram" => %{bot_token: bot_token, chat_id: chat_id}
         })}

      {:error, reason} ->
        {:error, "Failed to load config: #{inspect(reason)}"}
    end
  end

  defp get_config(config, field_names, env_value) do
    if is_list(field_names) do
      get_in(config, field_names)
    else
      Map.get(config, field_names)
    end
    |> then(fn
      value when value in [nil, ""] -> env_value
      value -> value
    end)
  end

  def schedules(config) do
    Map.get(config, "schedules", [])
  end

  def ping_config(config) do
    Map.get(config, "ping", %{
      "model" => "claude-sonnet-4-6",
      "max_tokens" => 10,
      "prompt" => "hi"
    })
  end

  def api_key(config), do: Map.get(config, :api_key)
end
