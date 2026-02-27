defmodule PingScheduler.Pinger do
  @api_url "https://api.anthropic.com/v1/messages"
  @default_max_retries 3
  @default_base_delay 5000

  def ping(api_key, ping_config) do
    model = Map.get(ping_config, "model", "claude-sonnet-4-6")
    max_tokens = Map.get(ping_config, "max_tokens", 10)
    prompt = Map.get(ping_config, "prompt", "hi")
    max_retries = Map.get(ping_config, "max_retries", @default_max_retries)
    base_delay = Map.get(ping_config, "retry_delay", @default_base_delay)

    ping_with_retry(api_key, model, max_tokens, prompt, max_retries, base_delay, 0, 0)
  end

  defp ping_with_retry(
         _api_key,
         _model,
         _max_tokens,
         _prompt,
         max_retries,
         _base_delay,
         _start_time,
         attempts
       )
       when attempts >= max_retries do
    {:error, "Max retries (#{max_retries}) exceeded", 0}
  end

  defp ping_with_retry(
         api_key,
         model,
         max_tokens,
         prompt,
         max_retries,
         base_delay,
         start_time,
         attempts
       ) do
    case send_ping(api_key, model, max_tokens, prompt) do
      {:ok, _response} ->
        result = if attempts > 0, do: "retry success (#{attempts})", else: "success"
        {:ok, result}

      {:error, reason} ->
        if attempts < max_retries - 1 do
          delay = calculate_delay(attempts, base_delay)
          Process.sleep(delay)

          ping_with_retry(
            api_key,
            model,
            max_tokens,
            prompt,
            max_retries,
            base_delay,
            start_time,
            attempts + 1
          )
        else
          {:error, reason}
        end
    end
  end

  defp calculate_delay(attempt, base_delay) do
    (base_delay * :math.pow(2, attempt)) |> round()
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
