defmodule PingScheduler.Config do
  @config_file "config/config.yaml"

  def load do
    config_path = Path.expand(@config_file, File.cwd!())

    case YamlElixir.read_from_file(config_path) do
      {:ok, config} ->
        api_key = get_api_key(config)
        {:ok, Map.put(config, :api_key, api_key)}

      {:error, reason} ->
        {:error, "Failed to load config: #{inspect(reason)}"}
    end
  end

  defp get_api_key(config) do
    config
    |> Map.get("api_key")
    |> then(fn
      nil -> System.get_env("ANTHROPIC_API_KEY")
      key -> key
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
