defmodule Miniapp.Chain.BlockListener do
  @moduledoc """
  Connects to a blockchain node via WebSocket and listens for new blocks.
  Currently implemented for Ethereum-compatible nodes via `eth_subscribe`.
  """

  use GenServer
  require Logger

  @type state :: %{
          ws_url: String.t(),
          conn_pid: pid() | nil,
          request_id: integer(),
          subscribed?: boolean()
        }

  # Public API
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # GenServer callbacks
  @impl true
  def init(_opts) do
    ws_url = Application.get_env(:miniapp, Miniapp.Chain)[:ws_url]
    state = %{ws_url: ws_url, conn_pid: nil, request_id: 0, subscribed?: false}
    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case connect_ws(state.ws_url) do
      {:ok, conn_pid} ->
        Process.monitor(conn_pid)
        {:noreply, %{state | conn_pid: conn_pid}, {:continue, :subscribe}}

      {:error, reason} ->
        Logger.error("BlockListener connect error: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, state}
    end
  end

  @impl true
  def handle_continue(:subscribe, %{conn_pid: conn_pid} = state) when is_pid(conn_pid) do
    id = state.request_id + 1

    payload = %{
      jsonrpc: "2.0",
      id: id,
      method: "eth_subscribe",
      params: ["newHeads"]
    }

    :ok = send_json(conn_pid, payload)
    {:noreply, %{state | request_id: id}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{conn_pid: pid} = state) do
    Logger.warning("BlockListener WS down: #{inspect(reason)}")
    schedule_reconnect()
    {:noreply, %{state | conn_pid: nil, subscribed?: false}}
  end

  # Incoming websocket JSON messages
  @impl true
  def handle_info({:ws_json, msg}, state) do
    case msg do
      %{"method" => "eth_subscription", "params" => %{"result" => result}} ->
        # new head notification
        with hex when is_binary(hex) <- Map.get(result, "number"),
             {block_number, _} <- Integer.parse(String.trim_leading(hex, "0x"), 16) do
          Miniapp.Chain.broadcast_block_number(block_number)
        else
          _ -> :noop
        end

        {:noreply, state}

      %{"id" => _id, "result" => _sub_id} ->
        {:noreply, %{state | subscribed?: true}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:reconnect, _}, state), do: handle_continue(:connect, state)

  def handle_info(_other, state), do: {:noreply, state}

  # Internal helpers
  defp connect_ws(nil), do: {:error, :no_ws_url_configured}

  defp connect_ws(ws_url) do
    # Use :websocket_client for low-level; here we simulate via a small port owner.
    # For simplicity and fewer deps, we use :gun for WS if available; but since
    # we added :websockex dependency, we could implement it there. To keep this
    # module decoupled, delegate actual WS to a small process below.
    Miniapp.Chain.WsClient.start_link(ws_url, self())
  end

  defp send_json(conn_pid, map) when is_pid(conn_pid) and is_map(map) do
    encoded = Jason.encode!(map)
    send(conn_pid, {:send, encoded})
    :ok
  end

  defp schedule_reconnect do
    Process.send_after(self(), {:reconnect, System.system_time(:second)}, :timer.seconds(3))
  end
end

defmodule Miniapp.Chain.WsClient do
  @moduledoc false
  use WebSockex
  require Logger

  def start_link(url, listener_pid) do
    state = %{listener: listener_pid}
    WebSockex.start_link(url, __MODULE__, state)
  end

  @impl true
  def handle_connect(_conn, state) do
    {:ok, state}
  end

  @impl true
  def handle_info({:send, json}, state) do
    {:reply, {:text, json}, state}
  end

  @impl true
  def handle_frame({:text, json}, %{listener: listener} = state) do
    case Jason.decode(json) do
      {:ok, map} -> send(listener, {:ws_json, map})
      {:error, reason} -> Logger.debug("WS decode error: #{inspect(reason)}")
    end

    {:ok, state}
  end

  def handle_frame(_other, state), do: {:ok, state}

  @impl true
  def terminate(reason, _state) do
    Logger.debug("WS terminate: #{inspect(reason)}")
    :ok
  end
end
