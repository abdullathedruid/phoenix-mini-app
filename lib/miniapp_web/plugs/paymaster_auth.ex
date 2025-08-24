defmodule MiniappWeb.Plugs.PaymasterAuth do
  @moduledoc """
  Authenticates access to the paymaster proxy using Phoenix.Token.

  Expects a `token` query param signed with the endpoint's secret key base and
  a dedicated salt. Tokens are short-lived to limit replay risk.
  """

  import Plug.Conn
  require Logger

  @behaviour Plug

  @salt "paymaster-proxy"
  @max_age_seconds 60

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    result =
      with [token] <- Map.get(conn.params, "token", []),
           {:ok, claims} <- verify_token(token),
           :ok <- maybe_verify_sender(conn, claims) do
        {:ok, claims}
      else
        [] -> {:error, :missing_token}
        {:error, reason} -> {:error, reason}
        :error -> {:error, :sender_mismatch}
        other -> {:error, other}
      end

    case result do
      {:ok, claims} -> assign(conn, :paymaster_claims, claims)
      {:error, reason} ->
        Logger.warning("paymaster auth failed: #{inspect(reason)} #{inspect(conn.request_path)} #{inspect(conn.method)}")

        conn
        |> send_resp(401, "unauthorized")
        |> halt()
    end
  end

  def sign_token(claims) when is_map(claims) do
    Phoenix.Token.sign(MiniappWeb.Endpoint, @salt, claims)
  end

  defp verify_token(token) do
    Phoenix.Token.verify(MiniappWeb.Endpoint, @salt, token, max_age: @max_age_seconds)
  end

  # Verify that the request body has the expected sender at params[0].sender
  defp maybe_verify_sender(%{body_params: body} = _conn, %{"sender" => expected}) when is_map(body) do
    actual = get_in(body, ["params", 0, "sender"])
    expected_norm = normalize_address(expected)
    actual_norm = normalize_address(actual)

    cond do
      is_nil(actual_norm) -> {:error, :sender_missing}
      actual_norm == expected_norm -> :ok
      true -> {:error, {:sender_mismatch, %{expected: expected_norm, actual: actual_norm}}}
    end
  end

  defp maybe_verify_sender(_conn, _claims), do: :error

  defp normalize_address(value) when is_binary(value), do: String.downcase(value)
  defp normalize_address(_), do: nil
end
