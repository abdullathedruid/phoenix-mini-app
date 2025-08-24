defmodule MiniappWeb.WalletLive do
  require Logger
  use MiniappWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Miniapp.Chain.subscribe_to_blocks()
    end

    {:ok,
     socket
     |> assign(:user_fid, nil)
     |> assign(:user_display_name, nil)
     |> assign(:user_pfp_url, nil)
     |> assign(:latest_block, nil)
     |> assign(:connected_address, nil)
     |> assign(:capabilities, %{
       atomic_status: :unsupported,
       auxiliary_funds: false,
       paymaster_service: false
     })}
  end

  @impl true
  def handle_event("miniapp:connect", %{"context" => context}, socket) do
    %{"user" => %{"fid" => user_fid} = user, "client" => %{"clientFid" => client_fid}} = context

    user_display_name = user |> Map.get("displayName")
    user_pfp_url = user |> Map.get("pfpUrl")

    {:noreply,
     socket
     # only get the account if we're connected as a miniapp
     |> push_event("client:request", %{action: "get_account"})
     |> assign(:user_fid, user_fid)
     |> assign(:user_display_name, user_display_name)
     |> assign(:user_pfp_url, user_pfp_url)
     |> assign(:client_fid, client_fid)}
  end

  @impl true
  def handle_event("get_capabilities", _params, %{assigns: %{connected_address: nil}} = socket) do
    {:noreply, socket |> put_flash(:error, "Please connect your wallet to continue")}
  end

  @impl true
  def handle_event(
        "get_capabilities",
        _params,
        %{assigns: %{connected_address: _connected_address}} = socket
      ) do
    {:noreply, socket |> push_event("client:request", %{action: "get_capabilities"})}
  end

  @impl true
  def handle_event("test_transaction", _params, %{assigns: %{connected_address: nil}} = socket) do
    # If not connected, prompt client to connect first
    {:noreply, socket |> push_event("client:request", %{action: "connect_account"})}
  end

  @impl true
  def handle_event(
        "test_transaction",
        _params,
        %{assigns: %{connected_address: connected_address}} = socket
      ) do
    calls = [
      %{"to" => connected_address}
    ]

    {:noreply,
     socket
     |> push_event("client:request", %{action: "send_calls", params: %{
        "calls" => calls,
        "capabilities" => %{"paymasterService" => %{"url" => paymaster_proxy_url_with_token(socket)}}
      }})
    }
  end

  @impl true
  def handle_event(
        "client:response",
        %{"action" => "get_capabilities", "ok" => true, "result" => capabilities},
        socket
      ) do
    parsed_capabilities = Miniapp.Wallet.Capabilities.parse(capabilities)

    Logger.info("get_capabilities completed with capabilities: #{inspect(parsed_capabilities)}")
    {:noreply, socket |> assign(:capabilities, parsed_capabilities)}
  end

  @impl true
  def handle_event(
        "client:response",
        %{"action" => "send_calls", "ok" => true, "result" => %{"response" => %{"id" => id}}},
        socket
      ) do
    case socket.assigns[:connected_address] do
      nil ->
        Logger.info("send_calls completed with id: #{id}")
      wallet_address ->
        Logger.info("Calls sent successfully - ID: #{id}, Wallet: #{wallet_address}")
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "client:response",
        %{"action" => "send_calls", "ok" => true, "result" => %{"id" => id}},
        socket
      ) do
    Logger.info("send_calls completed with id: #{id}")
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "client:response",
        %{"action" => "send_calls", "ok" => false, "error" => error},
        socket
      ) do
    # TODO: handle error - maybe the user rejected the transaction
    Logger.error("send_calls failed: #{inspect(error)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "client:response",
        %{"action" => "get_account", "ok" => true, "result" => %{"address" => address}},
        socket
      ) do
    # We got an account so we can assign it to the socket
    {:noreply,
     socket
     |> assign(:connected_address, address)
     |> push_event("client:request", %{action: "get_capabilities"})}
  end

  @impl true
  def handle_event(
        "client:response",
        %{"action" => "get_account", "ok" => true, "result" => result},
        socket
      )
      when result == %{} do
    # No address found, try to connect
    {:noreply, socket |> push_event("client:request", %{action: "connect_account"})}
  end

  @impl true
  def handle_event(
        "client:response",
        %{
          "action" => "connect_account",
          "ok" => true,
          "result" => %{"accounts" => [address | _]}
        },
        socket
      ) do
    # We connected so now we can get the account
    {:noreply,
     socket
     |> assign(:connected_address, address)
     |> push_event("client:request", %{action: "get_capabilities"})}
  end

  @impl true
  def handle_event(
        "client:response",
        %{"action" => action, "ok" => false, "error" => error},
        socket
      ) do
    Logger.error("Client action #{action} failed: #{inspect(error)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, unsigned_params, socket) do
    Logger.warning("Unhandled event: #{event} with params: #{inspect(unsigned_params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_block, block_number}, socket) when is_integer(block_number) do
    {:noreply, assign(socket, :latest_block, block_number)}
  end

  defp paymaster_proxy_url do
    MiniappWeb.Endpoint.url() <> "/api/paymaster"
  end

  defp paymaster_proxy_url_with_token(socket) do
    sender = socket.assigns[:connected_address]
    claims = %{
      "fid" => socket.assigns[:user_fid],
      "ts" => System.system_time(:second),
      "sender" => is_binary(sender) && String.downcase(sender)
    }
    token = MiniappWeb.Plugs.PaymasterAuth.sign_token(claims)
    paymaster_proxy_url() <> "?token=" <> token
  end
end
