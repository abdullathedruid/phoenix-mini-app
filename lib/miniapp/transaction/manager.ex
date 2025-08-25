defmodule Miniapp.Transaction.Manager do
  def request_transaction(transaction, user_address) do
    transaction_id = generate_transaction_id()

    child_spec = %{
      id: Miniapp.Transaction.Orchestrator,
      start:
        {Miniapp.Transaction.Orchestrator, :start_link,
         [
           [
             transaction_id: transaction_id,
             user_address: user_address,
             transaction: transaction
           ]
         ]}
    }

    with {:ok, _pid} <- DynamicSupervisor.start_child(Miniapp.Transaction.Supervisor, child_spec) do
      {:ok, transaction_id}
    end
  end

  defp generate_transaction_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
