defmodule Miniapp.Transaction.Lifecycle do
  alias Miniapp.Client.Dispatcher
  alias Miniapp.Transaction.{Monitor, Paymaster, Pubsub}

  require Logger
  @behaviour :gen_statem

  defstruct transaction_id: nil,
            user_address: nil,
            user_fid: nil,
            transaction: nil,
            state: nil,
            started_at_root: nil,
            started_at_building: nil,
            started_at_requested: nil,
            started_at_waiting_for_calls_status: nil,
            send_calls_id: nil

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
    user_fid = Keyword.get(opts, :user_fid)

    Monitor.execute([:parent, :started], %{}, %{
      transaction_id: transaction_id,
      user_address: user_address
    })

    state = %__MODULE__{
      transaction_id: transaction_id,
      user_address: user_address,
      user_fid: user_fid,
      transaction: transaction,
      started_at_root: System.monotonic_time()
    }

    {:ok, :building, state, {:next_event, :internal, :build_transaction}}
  end

  @impl :gen_statem
  def terminate(reason, _current_state, data) do
    duration_ms = get_duration_ms(data.started_at_root)

    status =
      case reason do
        {:shutdown, :transaction_completed} -> :success
        {:shutdown, status_atom} when is_atom(status_atom) -> status_atom
        :normal -> :success
        other -> other
      end

    Monitor.execute(
      [
        :parent,
        :ended
      ],
      %{duration_ms: duration_ms},
      %{
        transaction_id: data.transaction_id,
        user_address: data.user_address,
        status: status
      }
    )

    :ok
  end

  # State callbacks

  def building(:enter, :building, data) do
    data = %{data | started_at_building: System.monotonic_time()}

    Monitor.execute([:building, :started], %{}, %{
      transaction_id: data.transaction_id,
      user_address: data.user_address
    })

    {:keep_state, data}
  end

  def building(:internal, :build_transaction, data) do
    # Build capabilities including paymaster if available
    capabilities = Paymaster.build_capabilities(data.user_address, data.user_fid)

    # Build the transaction into calls using the Transaction protocol
    calls = Miniapp.Transaction.build(data.transaction)

    %Miniapp.Client.Events.SendCalls{
      account: data.user_address,
      calls: calls,
      capabilities: capabilities
    }
    |> Dispatcher.build_request(id: data.transaction_id)
    |> Pubsub.broadcast_event(data.user_address)

    Monitor.execute(
      [:building, :ended],
      %{
        duration_ms: get_duration_ms(data.started_at_building)
      },
      %{
        transaction_id: data.transaction_id,
        user_address: data.user_address,
        status: :success
      }
    )

    {:next_state, :requested, data}
  end

  def requested(:enter, :building, data) do
    data = %{data | started_at_requested: System.monotonic_time()}

    Monitor.execute([:requested, :started], %{}, %{
      transaction_id: data.transaction_id,
      user_address: data.user_address
    })

    {:keep_state, data}
  end

  def requested(:cast, {:send_calls, %{"ok" => false} = _response}, data) do
    Monitor.execute(
      [:requested, :ended],
      %{
        duration_ms: get_duration_ms(data.started_at_requested)
      },
      %{
        transaction_id: data.transaction_id,
        user_address: data.user_address,
        status: :user_rejected
      }
    )

    {:stop, {:shutdown, :user_rejected}}
  end

  def requested(
        :cast,
        {:send_calls, %{"ok" => true, "result" => %{"id" => send_calls_id}} = _response},
        data
      ) do
    data = %{data | send_calls_id: send_calls_id}

    Monitor.execute(
      [:requested, :ended],
      %{
        duration_ms: get_duration_ms(data.started_at_requested)
      },
      %{
        transaction_id: data.transaction_id,
        user_address: data.user_address,
        status: :success
      }
    )

    {:next_state, :waiting_for_calls_status, data}
  end

  def waiting_for_calls_status(:enter, :requested, data) do
    data = %{data | started_at_waiting_for_calls_status: System.monotonic_time()}

    %Miniapp.Client.Events.WaitForCallsStatus{
      id: data.send_calls_id
    }
    |> Dispatcher.build_request(id: data.transaction_id)
    |> Pubsub.broadcast_event(data.user_address)

    Monitor.execute([:waiting_for_calls_status, :started], %{}, %{
      transaction_id: data.transaction_id,
      user_address: data.user_address
    })

    {:keep_state, data}
  end

  def waiting_for_calls_status(
        :cast,
        {:wait_for_calls_status, %{"ok" => false} = _response},
        data
      ) do
    Monitor.execute(
      [:waiting_for_calls_status, :ended],
      %{
        duration_ms: get_duration_ms(data.started_at_waiting_for_calls_status)
      },
      %{
        transaction_id: data.transaction_id,
        user_address: data.user_address,
        status: :transaction_failed
      }
    )

    {:stop, {:shutdown, :transaction_failed}}
  end

  def waiting_for_calls_status(:cast, {:wait_for_calls_status, %{"ok" => true} = _response}, data) do
    Monitor.execute(
      [:waiting_for_calls_status, :ended],
      %{
        duration_ms: get_duration_ms(data.started_at_waiting_for_calls_status)
      },
      %{
        transaction_id: data.transaction_id,
        user_address: data.user_address,
        status: :success
      }
    )

    {:stop, {:shutdown, :transaction_completed}}
  end

  @impl :gen_statem
  def handle_event(atom, oldState, currentState, data) do
    Logger.warning(
      "Unhandled event #{inspect(atom)} #{inspect(oldState)} #{inspect(currentState)} #{inspect(data)}"
    )

    :keep_state_and_data
  end

  defp via_tuple(transaction_id),
    do: {:via, Registry, {Miniapp.Transaction.Registry, transaction_id}}

  defp get_duration_ms(started_at) do
    duration_native = System.monotonic_time() - (started_at || System.monotonic_time())
    System.convert_time_unit(duration_native, :native, :millisecond)
  end
end
