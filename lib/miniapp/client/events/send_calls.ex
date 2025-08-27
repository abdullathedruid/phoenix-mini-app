defmodule Miniapp.Client.Events.SendCalls do
  @enforce_keys [:calls]
  defstruct account: nil,
            calls: [],
            capabilities: nil,
            chain_id: nil

  @type t :: %__MODULE__{
          account: String.t(),
          calls: list(map()),
          capabilities: map(),
          chain_id: non_neg_integer()
        }

  def params(%__MODULE__{} = event) do
    params = %{"calls" => event.calls}

    params =
      if event.capabilities, do: Map.put(params, "capabilities", event.capabilities), else: params

    params = if event.chain_id, do: Map.put(params, "chainId", event.chain_id), else: params
    params = if event.account, do: Map.put(params, "account", event.account), else: params
    params
  end
end

defmodule Miniapp.Client.Events.SendCallsResponse do
  @enforce_keys [:id]
  defstruct id: nil,
            capabilities: nil

  @type t :: %__MODULE__{
          id: String.t(),
          capabilities: map()
        }
end
