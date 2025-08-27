defmodule Miniapp.Transaction.Lifecycle do
  alias Miniapp.Client.Dispatcher
  alias Miniapp.Transaction.{Monitor, Pubsub}

  require Logger
  @behaviour :gen_statem

  defstruct ~w(transaction_id user_address transaction state started_at send_calls_id)a

  @impl :gen_statem
  def callback_mode, do: [:state_functions, :state_enter]

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
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

    Monitor.execute(:started, %{}, %{transaction_id: transaction_id})

    state = %__MODULE__{
      transaction_id: transaction_id,
      user_address: user_address,
      transaction: transaction
    }

    {:ok, :building, state, {:next_event, :internal, :build_transaction}}
  end

  @impl :gen_statem
  def terminate(_reason, _current_state, data) do
    Monitor.execute([:ended], %{}, %{transaction_id: data.transaction_id})
    :ok
  end

  # State callbacks

  def building(:enter, :building, data) do
    Monitor.execute([:building, :started], %{}, %{transaction_id: data.transaction_id})

    :keep_state_and_data
  end

  def building(:internal, :build_transaction, data) do
    # DO WORK
    %Miniapp.Client.Events.SendCalls{
      account: data.user_address,
      calls: data.transaction,
      capabilities: %{}
    }
    |> Dispatcher.build_request(id: data.transaction_id)
    |> Pubsub.broadcast_event(data.user_address)

    Monitor.execute([:building, :ended], %{}, %{transaction_id: data.transaction_id})

    {:next_state, :requested, data}
  end

  def requested(:enter, :building, data) do
    Monitor.execute([:requested, :started], %{}, %{transaction_id: data.transaction_id})

    :keep_state_and_data
  end

  def requested(:cast, {:send_calls, %{"ok" => false} = response}, data) do
    Logger.warning("Received send calls failure #{inspect(response)}")
    Monitor.execute([:requested, :ended], %{}, %{transaction_id: data.transaction_id})
    {:stop, {:shutdown, :user_rejected}}
  end

  def requested(
        :cast,
        {:send_calls, %{"ok" => true, "result" => %{"id" => send_calls_id}} = response},
        data
      ) do
    Logger.info("Received send calls success #{inspect(response)}")
    data = %{data | send_calls_id: send_calls_id}
    Monitor.execute([:requested, :ended], %{}, %{transaction_id: data.transaction_id})
    {:next_state, :waiting_for_calls_status, data}
  end

  def waiting_for_calls_status(:enter, :requested, data) do
    %Miniapp.Client.Events.WaitForCallsStatus{
      id: data.send_calls_id
    }
    |> Dispatcher.build_request(id: data.transaction_id)
    |> Pubsub.broadcast_event(data.user_address)

    Monitor.execute([:waiting_for_calls_status, :started], %{}, %{
      transaction_id: data.transaction_id
    })

    :keep_state_and_data
  end

  def waiting_for_calls_status(:cast, {:wait_for_calls_status, %{"ok" => false} = response}, data) do
    Logger.warning("Received wait for calls status failure #{inspect(response)}")

    Monitor.execute([:waiting_for_calls_status, :ended], %{}, %{
      transaction_id: data.transaction_id
    })

    {:stop, {:shutdown, :transaction_failed}}
  end

  def waiting_for_calls_status(:cast, {:wait_for_calls_status, %{"ok" => true} = response}, data) do
    Logger.info("Received wait for calls status success #{inspect(response)}")

    Monitor.execute([:waiting_for_calls_status, :ended], %{}, %{
      transaction_id: data.transaction_id
    })

    {:stop, {:shutdown, :transaction_completed}}
  end

  @impl :gen_statem
  def handle_event(atom, oldState, currentState, data) do
    Logger.warning("Unhandled event")
    dbg()
    :error
  end

  defp via_tuple(transaction_id),
    do: {:via, Registry, {Miniapp.Transaction.Registry, transaction_id}}
end
