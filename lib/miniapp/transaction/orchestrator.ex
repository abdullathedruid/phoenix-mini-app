defmodule Miniapp.Transaction.Orchestrator do
  use GenServer, restart: :temporary
  alias Miniapp.Transaction.{Events, Pubsub}

  defstruct ~w(transaction_id user_address transaction state started_at)a

  # Client API
  def start_link(opts) do
    transaction_id = Keyword.fetch!(opts, :transaction_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(transaction_id))
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
  def handle_info(:start_transaction, state) do
    # We might need to do some logic here
    new_state = %{state | state: :awaiting_signature}

    event = %Events.RequestSendCalls{
      transaction_id: state.transaction_id,
      calls: state.transaction,
      capabilities: %{},
      timestamp: System.system_time(:millisecond)
    }

    Pubsub.broadcast_event(state.user_address, event)

    {:noreply, new_state}
  end

  defp via_tuple(transaction_id),
    do: {:via, Registry, {Miniapp.Transaction.Registry, transaction_id}}
end
