defmodule Miniapp.Wallet.Capabilities do
  @moduledoc """
  Helpers for parsing capabilities from the client.
  """
  @type t() :: %{
    atomic_status: :unsupported | :ready | :supported,
    auxiliary_funds: boolean(),
    paymaster_service: boolean()
  }

  @spec parse(map()) :: t()
  def parse(%{"8453" => capabilities}) do
    atomic_status =
      case get_in(capabilities, ["atomic", "status"]) do
        "supported" -> :supported
        "ready" -> :ready
        _ -> :unsupported
      end

    %{
      atomic_status: atomic_status,
      auxiliary_funds: get_in(capabilities, ["auxiliaryFunds", "supported"]) in [true, "true"],
      paymaster_service: get_in(capabilities, ["paymasterService", "supported"]) in [true, "true"]
    }
  end

  # If we can't parse the capabilities, we default to unsupported
  def parse(_) do
    %{atomic_status: :unsupported, auxiliary_funds: false, paymaster_service: false}
  end
end
