defmodule MiniappWeb.WalletLive do
  require Logger
  use MiniappWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("wallet:connect", %{"context" => context}, socket) do
    Logger.info("Wallet connected: #{inspect(context)}")
    {:noreply, socket}
  end

  def handle_event(event, unsigned_params, socket) do
    Logger.warning("Unhandled event: #{event} with params: #{inspect(unsigned_params)}")
    {:noreply, socket}
  end
end
