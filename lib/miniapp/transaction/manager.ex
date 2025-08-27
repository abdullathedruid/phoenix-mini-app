defmodule Miniapp.Transaction.Manager do
  alias Miniapp.Transaction.Lifecycle

  def request_transaction(transaction, user_address, opts \\ []) do
    transaction_id = generate_transaction_id()

    start_opts = [
      transaction_id: transaction_id,
      user_address: user_address,
      transaction: transaction,
      user_fid: Keyword.get(opts, :user_fid),
      client_name: Keyword.get(opts, :client_name)
    ]

    with {:ok, _pid} <-
           DynamicSupervisor.start_child(
             Miniapp.Transaction.Supervisor,
             Lifecycle.child_spec(start_opts)
           ) do
      {:ok, transaction_id}
    end
  end

  def report_send_calls_response(transaction_id, response),
    do: Lifecycle.report_send_calls_response(transaction_id, response)

  def report_wait_for_calls_status(transaction_id, response),
    do: Lifecycle.report_wait_for_calls_status(transaction_id, response)

  defp generate_transaction_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
