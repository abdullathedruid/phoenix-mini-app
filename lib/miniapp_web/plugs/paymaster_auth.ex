defmodule MiniappWeb.Plugs.PaymasterAuth do
  @moduledoc """
  Authenticates access to the paymaster proxy using Phoenix.Token.

  Expects a `token` query param signed with the endpoint's secret key base and
  a dedicated salt. Tokens are short-lived to limit replay risk.
  """

  import Plug.Conn

  @behaviour Plug

  @salt "paymaster-proxy"
  @max_age_seconds 60

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with [token] <- Map.get(conn.params, "token", []),
         {:ok, claims} <- verify_token(token),
         :ok <- maybe_verify_sender(conn, claims) do
      assign(conn, :paymaster_claims, claims)
    else
      _ ->
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
  defp maybe_verify_sender(%{body_params: body}, %{"sender" => expected}) when is_map(body) do
    actual = get_in(body, ["params", 0, "sender"])
    expected_norm = normalize_address(expected)
    actual_norm = normalize_address(actual)

    if is_binary(actual_norm) and actual_norm == expected_norm, do: :ok, else: :error
  end

  defp maybe_verify_sender(_conn, _claims), do: :error

  defp normalize_address(value) when is_binary(value), do: String.downcase(value)
  defp normalize_address(_), do: nil
end
