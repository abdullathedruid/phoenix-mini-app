defmodule Miniapp.Transaction.Lifecycle do
  alias Miniapp.Transaction.Monitor
  alias Miniapp.Transaction.{Events, Pubsub}
  require Logger
  @behaviour :gen_statem

  defstruct ~w(transaction_id user_address transaction state started_at)a

  @impl :gen_statem
  def callback_mode, do: [:state_functions, :state_enter]

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
    }
  end

  # Client API
  def start_link(opts) do
    transaction_id = Keyword.fetch!(opts, :transaction_id)
    :gen_statem.start_link(via_tuple(transaction_id), __MODULE__, opts, [])
  end

  def report_send_calls_response(transaction_id, response),
    do: :gen_statem.cast(via_tuple(transaction_id), {:send_calls, response})

  def report_wait_for_calls_status(transaction_id, response),
    do: :gen_statem.cast(via_tuple(transaction_id), {:wait_for_calls_status, response})

  # Mandatory callbacks

  @impl :gen_statem
  def init(opts) do
    transaction_id = Keyword.fetch!(opts, :transaction_id)
    user_address = Keyword.fetch!(opts, :user_address)
    transaction = Keyword.fetch!(opts, :transaction)

    measurements = %{system_time: System.system_time(), monotonic_time: System.monotonic_time()}
    Monitor.execute(:started, measurements, %{transaction_id: transaction_id})

    state = %__MODULE__{
      transaction_id: transaction_id,
      user_address: user_address,
      transaction: transaction,
      started_at: System.system_time(:millisecond)
    }

    {:ok, :building, state, {:next_event, :internal, :build_transaction}}
  end

  @impl :gen_statem
  def terminate(reason, current_state, data) do
    Logger.warning("Terminating")
    dbg()
    :ok
  end

  # State callbacks

  def building(:enter, :building, data) do
    measurements = %{system_time: System.system_time(), monotonic_time: System.monotonic_time()}
    Monitor.execute([:building, :started], measurements, %{transaction_id: data.transaction_id})

    :keep_state_and_data
  end

  def building(:internal, :build_transaction, data) do
    # DO WORK
    event = %Events.RequestSendCalls{
      transaction_id: data.transaction_id,
      calls: data.transaction,
      capabilities: %{},
      timestamp: System.system_time(:millisecond)
    }

    Pubsub.broadcast_event(data.user_address, event)

    measurements = %{system_time: System.system_time(), monotonic_time: System.monotonic_time()}
    Monitor.execute([:building, :ended], measurements, %{transaction_id: data.transaction_id})

    {:next_state, :requested, data}
  end

  def requested(:enter, :building, data) do
    measurements = %{system_time: System.system_time(), monotonic_time: System.monotonic_time()}
    Monitor.execute([:requested, :started], measurements, %{transaction_id: data.transaction_id})

    :keep_state_and_data
  end

  def requested(:cast, {:send_calls, response}, data) do
    Logger.info("Received send calls response #{inspect(response)}")
    {:keep_state, data}
  end

  @impl true
  def handle_info(:start_transaction, %{state: :initializing} = state) do
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

    measurements = %{system_time: event.timestamp}
    :telemetry.execute([:transaction, :broadcasted], measurements, %{call_id: send_calls_id})

    Pubsub.broadcast_event(state.user_address, event)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:send_calls, _response}, state) do
    new_state = %{state | state: :failed}

    measurements = %{duration: System.monotonic_time() - state.started_at}
    :telemetry.execute([:transaction, :failed], measurements, %{reason: :send_calls_failure})

    {:stop, :normal, new_state}
  end

  @impl true
  def handle_cast(
        {:wait_for_calls_status,
         %{
           "ok" => true,
           "id" => transaction_id,
           "result" => %{
             "receipts" => receipts,
             "status" => status
           }
         }},
        %{state: :calls_sent, transaction_id: transaction_id} = state
      ) do
    new_state = %{state | state: :completed}

    measurements = %{duration: System.monotonic_time() - state.started_at}
    :telemetry.execute([:transaction, :completed], measurements, %{receipts: receipts, status: status})

    {:stop, :normal, new_state}
  end

  @impl true
  def handle_cast({:wait_for_calls_status, _response}, state) do
    new_state = %{state | state: :failed}

    measurements = %{duration: System.monotonic_time() - state.started_at}
    :telemetry.execute([:transaction, :failed], measurements, %{reason: :wait_for_calls_status_failure})

    {:stop, :normal, new_state}
  end

  def handle_event(atom, oldState, currentState, data) do
    Logger.warning("Unhandled event")
    dbg()
    :error
  end

  defp via_tuple(transaction_id),
    do: {:via, Registry, {Miniapp.Transaction.Registry, transaction_id}}
end
