defmodule PingScheduler.Pinger do
  @api_url "https://api.anthropic.com/v1/messages"

  def ping(api_key, ping_config) do
    model = Map.get(ping_config, "model", "claude-sonnet-4-6")
    max_tokens = Map.get(ping_config, "max_tokens", 10)
    prompt = Map.get(ping_config, "prompt", "hi")

    start_time = System.system_time(:millisecond)

    case send_ping(api_key, model, max_tokens, prompt) do
      {:ok, _response} ->
        duration = System.system_time(:millisecond) - start_time
        {:ok, :success, duration}

      {:error, _reason} ->
        case send_ping(api_key, model, max_tokens, prompt) do
          {:ok, _response} ->
            duration = System.system_time(:millisecond) - start_time
            {:ok, :retried_success, duration}

          {:error, reason} ->
            duration = System.system_time(:millisecond) - start_time
            {:error, reason, duration}
        end
    end
  end

  defp send_ping(api_key, model, max_tokens, prompt) do
    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: model,
        max_tokens: max_tokens,
        messages: [%{role: "user", content: prompt}]
      })

    case Req.post(@api_url, headers: headers, body: body) do
      {:ok, %{status: 200}} ->
        {:ok, "success"}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end
