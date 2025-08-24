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
     |> assign(:latest_block, nil)}
  end

  @impl true
  def handle_event("miniapp:connect", %{"context" => context}, socket) do
    %{"user" => %{"fid" => user_fid} = user, "client" => %{"clientFid" => client_fid}} = context

    user_display_name = user |> Map.get("displayName")
    user_pfp_url = user |> Map.get("pfpUrl")

    {:noreply,
     socket
     |> assign(:user_fid, user_fid)
     |> assign(:user_display_name, user_display_name)
     |> assign(:user_pfp_url, user_pfp_url)
     |> assign(:client_fid, client_fid)}
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
end
