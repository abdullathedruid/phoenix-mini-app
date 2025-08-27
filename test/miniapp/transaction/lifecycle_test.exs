defmodule Miniapp.Transaction.LifecycleTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Miniapp.Transaction.Lifecycle

  setup do
    # Start the registry for testing if not already started
    case Registry.start_link(keys: :unique, name: Miniapp.Transaction.Registry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    transaction_id = "test_tx_#{:rand.uniform(10000)}"
    user_address = "0x1234567890abcdef"
    transaction = [%{to: "0xabcd", value: 100}]

    opts = [
      transaction_id: transaction_id,
      user_address: user_address,
      transaction: transaction
    ]

    {:ok, opts: opts, transaction_id: transaction_id, user_address: user_address, transaction: transaction}
  end

  describe "callback_mode/0" do
    test "returns correct callback mode" do
      assert Lifecycle.callback_mode() == [:state_functions, :state_enter]
    end
  end

  describe "init/1" do
    test "initializes state correctly", %{opts: opts, transaction_id: transaction_id, user_address: user_address, transaction: transaction} do
      result = Lifecycle.init(opts)

      assert {:ok, :building, %Lifecycle{} = state, {:next_event, :internal, :build_transaction}} = result
      assert state.transaction_id == transaction_id
      assert state.user_address == user_address
      assert state.transaction == transaction
      assert is_integer(state.started_at_root)
      assert state.state == nil
    end

    test "requires transaction_id" do
      opts = [user_address: "0x1234", transaction: []]
      assert_raise KeyError, fn -> Lifecycle.init(opts) end
    end

    test "requires user_address" do
      opts = [transaction_id: "tx123", transaction: []]
      assert_raise KeyError, fn -> Lifecycle.init(opts) end
    end

    test "requires transaction" do
      opts = [transaction_id: "tx123", user_address: "0x1234"]
      assert_raise KeyError, fn -> Lifecycle.init(opts) end
    end
  end

  describe "state machine lifecycle" do
    test "starts and processes states correctly", %{opts: opts} do
      # Trap exits so that the test doesn't fail when the process terminates
      Process.flag(:trap_exit, true)
      
      {:ok, pid} = :gen_statem.start_link(Lifecycle, opts, [])
      
      # Give it time to process the initial build event
      :timer.sleep(100)
      
      # The process should be alive and have transitioned to requested state
      assert Process.alive?(pid)
      
      # Test successful send_calls response
      response = %{"ok" => true, "result" => %{"id" => "send_calls_123"}}
      :gen_statem.cast(pid, {:send_calls, response})
      
      :timer.sleep(50)
      
      # Process should still be alive and now waiting for calls status
      assert Process.alive?(pid)
      
      # Test successful wait_for_calls_status response
      success_response = %{"ok" => true}
      :gen_statem.cast(pid, {:wait_for_calls_status, success_response})
      
      # Process should terminate with transaction_completed
      assert_receive {:EXIT, ^pid, {:shutdown, :transaction_completed}}, 1000
    end

    test "handles user rejection", %{opts: opts} do
      Process.flag(:trap_exit, true)
      
      {:ok, pid} = :gen_statem.start_link(Lifecycle, opts, [])
      
      # Wait for building to complete
      :timer.sleep(100)
      
      # Send user rejection response
      response = %{"ok" => false}
      :gen_statem.cast(pid, {:send_calls, response})
      
      # Process should terminate with user_rejected
      assert_receive {:EXIT, ^pid, {:shutdown, :user_rejected}}, 1000
    end

    test "handles transaction failure", %{opts: opts} do
      Process.flag(:trap_exit, true)
      
      {:ok, pid} = :gen_statem.start_link(Lifecycle, opts, [])
      
      # Navigate to waiting_for_calls_status state
      :timer.sleep(100)
      success_response = %{"ok" => true, "result" => %{"id" => "send_calls_789"}}
      :gen_statem.cast(pid, {:send_calls, success_response})
      :timer.sleep(50)
      
      # Send transaction failure response
      failure_response = %{"ok" => false}
      :gen_statem.cast(pid, {:wait_for_calls_status, failure_response})
      
      # Process should terminate with transaction_failed
      assert_receive {:EXIT, ^pid, {:shutdown, :transaction_failed}}, 1000
    end
  end

  describe "terminate/3" do
    test "handles different termination reasons" do
      state = %Lifecycle{
        transaction_id: "test_tx",
        user_address: "0x1234",
        started_at_root: System.monotonic_time()
      }

      # Test successful completion
      assert :ok = Lifecycle.terminate({:shutdown, :transaction_completed}, :some_state, state)
      
      # Test user rejection
      assert :ok = Lifecycle.terminate({:shutdown, :user_rejected}, :some_state, state)
      
      # Test transaction failure
      assert :ok = Lifecycle.terminate({:shutdown, :transaction_failed}, :some_state, state)
      
      # Test normal termination
      assert :ok = Lifecycle.terminate(:normal, :some_state, state)
    end
  end

  describe "handle_event/4" do
    test "logs unhandled events" do
      # Test the handle_event function directly
      state = %Lifecycle{
        transaction_id: "test_tx",
        user_address: "0x1234"
      }
      
      log_output = capture_log(fn ->
        result = Lifecycle.handle_event(:unknown_event, :old_state, :current_state, state)
        assert result == :keep_state_and_data
      end)
      
      assert log_output =~ "Unhandled event"
    end
  end

  describe "client API" do
    test "report_send_calls_response/2 sends cast message", %{transaction_id: transaction_id} do
      opts = [
        transaction_id: transaction_id,
        user_address: "0x1234",
        transaction: []
      ]
      
      # Start a process to receive the cast
      {:ok, _pid} = :gen_statem.start_link({:via, Registry, {Miniapp.Transaction.Registry, transaction_id}}, Lifecycle, opts, [])
      
      response = %{"ok" => true, "result" => %{"id" => "test_id"}}
      
      # This should not raise an error
      assert :ok = Lifecycle.report_send_calls_response(transaction_id, response)
    end

    test "report_wait_for_calls_status/2 sends cast message", %{transaction_id: transaction_id} do
      opts = [
        transaction_id: transaction_id,
        user_address: "0x1234", 
        transaction: []
      ]
      
      # Start a process to receive the cast
      {:ok, _pid} = :gen_statem.start_link({:via, Registry, {Miniapp.Transaction.Registry, transaction_id}}, Lifecycle, opts, [])
      
      response = %{"ok" => true}
      
      # This should not raise an error
      assert :ok = Lifecycle.report_wait_for_calls_status(transaction_id, response)
    end
  end

  describe "child_spec/1" do
    test "returns correct child spec" do
      opts = [transaction_id: "test", user_address: "0x1234", transaction: []]
      spec = Lifecycle.child_spec(opts)
      
      assert spec.id == Lifecycle
      assert spec.restart == :transient
      assert {Lifecycle, :start_link, [^opts]} = spec.start
    end
  end
end