defmodule Miniapp.Transaction.Paymaster do
  @moduledoc """
  Handles paymaster URL generation and capabilities for transactions.
  """

  @doc """
  Builds paymaster capabilities for a transaction if paymaster is supported and configured.
  
  Returns a map with paymaster service URL if conditions are met, otherwise returns empty map.
  """
  @spec build_capabilities(user_address :: String.t(), user_fid :: integer() | nil) :: map()
  def build_capabilities(user_address, user_fid) when is_binary(user_address) do
    case paymaster_proxy_url_with_token(user_address, user_fid) do
      {:ok, paymaster_url} ->
        %{
          "paymasterService" => %{
            "url" => paymaster_url
          }
        }

      :error ->
        %{}
    end
  end

  def build_capabilities(_user_address, _user_fid), do: %{}

  @doc """
  Generates a signed paymaster proxy URL with authentication token.
  
  Returns {:ok, url} if paymaster is configured, :error otherwise.
  """
  @spec paymaster_proxy_url_with_token(user_address :: String.t(), user_fid :: integer() | nil) ::
          {:ok, String.t()} | :error
  def paymaster_proxy_url_with_token(user_address, user_fid) do
    with {:ok, base_url} <- paymaster_proxy_url(),
         {:ok, token} <- sign_paymaster_token(user_address, user_fid) do
      {:ok, base_url <> "?token=" <> token}
    end
  end

  defp paymaster_proxy_url do
    case System.get_env("PAYMASTER_URL") do
      nil -> :error
      _url -> {:ok, MiniappWeb.Endpoint.url() <> "/api/paymaster"}
    end
  end

  defp sign_paymaster_token(user_address, user_fid) when is_binary(user_address) do
    claims = %{
      "fid" => user_fid,
      "ts" => System.system_time(:second),
      "sender" => String.downcase(user_address)
    }

    token = MiniappWeb.Plugs.PaymasterAuth.sign_token(claims)
    {:ok, token}
  end

  defp sign_paymaster_token(_user_address, _user_fid), do: :error
end