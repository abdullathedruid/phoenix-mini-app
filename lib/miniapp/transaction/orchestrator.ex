defmodule Miniapp.Transaction.Orchestrator do
  use GenServer, restart: :temporary
  alias Miniapp.Transaction.{Events, Pubsub}

  defstruct ~w(transaction_id user_address transaction state started_at)a

  # Client API
  def start_link(opts) do
    transaction_id = Keyword.fetch!(opts, :transaction_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(transaction_id))
  end

  def report_send_calls_response(transaction_id, response) do
    GenServer.cast(via_tuple(transaction_id), {:send_calls, response})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    transaction_id = Keyword.fetch!(opts, :transaction_id)
    user_address = Keyword.fetch!(opts, :user_address)
    transaction = Keyword.fetch!(opts, :transaction)

    state = %__MODULE__{
      transaction_id: transaction_id,
      user_address: user_address,
      transaction: transaction,
      state: :initializing,
      started_at: System.monotonic_time(:millisecond)
    }

    # Start the transaction flow
    send(self(), :start_transaction)

    {:ok, state}
  end

  @impl true
  def handle_info(:start_transaction = msg, %{state: :initializing} = state) do
    # We might need to do some logic here
    new_state = %{state | state: :awaiting_send_calls}

    event = %Events.RequestSendCalls{
      transaction_id: state.transaction_id,
      calls: state.transaction,
      capabilities: %{},
      timestamp: System.system_time(:millisecond)
    }

    Pubsub.broadcast_event(state.user_address, event)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(
        {:send_calls,
         %{
           "ok" => true,
           "result" => %{"id" => send_calls_id} = response,
           "id" => transaction_id
         }},
        %{state: :awaiting_send_calls, transaction_id: transaction_id} = state
      ) do
    new_state = %{state | state: :calls_sent}

    event = %Events.RequestPollSendCalls{
      transaction_id: state.transaction_id,
      send_calls_id: send_calls_id,
      capabilities: Map.get(response, "capabilities"),
      timestamp: System.system_time(:millisecond)
    }

    Pubsub.broadcast_event(state.user_address, event)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:send_calls, _response}, state) do
    new_state = %{state | state: :failed}

    {:stop, :normal, new_state}
  end

  defp via_tuple(transaction_id),
    do: {:via, Registry, {Miniapp.Transaction.Registry, transaction_id}}
end
