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
      with {:ok, token} <- fetch_token(conn.params),
           {:ok, claims} <- verify_token(token),
           :ok <- maybe_verify_sender(conn, claims) do
        {:ok, claims}
      else
        {:error, reason} -> {:error, reason}
        other -> {:error, other}
      end

    case result do
      {:ok, claims} -> assign(conn, :paymaster_claims, claims)
      {:error, reason} ->
        payload = build_error_payload(conn, reason)

        Logger.warning("paymaster auth failed #{inspect(payload)} #{inspect(conn.request_path)} #{inspect(conn.method)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(payload))
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
  defp maybe_verify_sender(%{body_params: %{"params" => [%{"sender" => actual} | _]}} = _conn, %{"sender" => expected}) do
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

  defp fetch_token(params) when is_map(params) do
    case Map.get(params, "token") do
      token when is_binary(token) and byte_size(token) > 0 -> {:ok, token}
      [token] when is_binary(token) and byte_size(token) > 0 -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp build_error_payload(conn, reason) do
    %{
      "error" => "unauthorized",
      "reason" => format_reason(reason),
      "details" => reason_details(reason),
      "path" => conn.request_path,
      "method" => conn.method
    }
  end

  defp format_reason(:missing_token), do: "missing_token"
  defp format_reason(:sender_mismatch), do: "sender_mismatch"
  defp format_reason(:sender_missing), do: "sender_missing"
  defp format_reason(:invalid), do: "invalid_token"
  defp format_reason(:expired), do: "expired_token"
  defp format_reason({:sender_mismatch, _}), do: "sender_mismatch"
  defp format_reason(other) when is_atom(other), do: Atom.to_string(other)
  defp format_reason(other), do: inspect(other)

  defp reason_details({:sender_mismatch, %{expected: e, actual: a}}), do: %{expected: e, actual: a}
  defp reason_details(_), do: nil
end
