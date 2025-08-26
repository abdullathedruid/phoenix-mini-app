defmodule Miniapp.Transaction.Manager do
  alias Miniapp.Transaction.Orchestrator

  def request_transaction(transaction, user_address) do
    transaction_id = generate_transaction_id()

    start_opts = [
      transaction_id: transaction_id,
      user_address: user_address,
      transaction: transaction
    ]

    with {:ok, _pid} <-
           DynamicSupervisor.start_child(
             Miniapp.Transaction.Supervisor,
             {Miniapp.Transaction.Orchestrator, start_opts}
           ) do
      {:ok, transaction_id}
    end
  end

  def report_send_calls_response(transaction_id, response),
    do: Orchestrator.report_send_calls_response(transaction_id, response)

  defp generate_transaction_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
