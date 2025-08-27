defmodule Miniapp.Transaction.EmptySendToSelf do
  @moduledoc """
  Transaction module for empty send-to-self transactions.
  
  This creates a transaction that sends 0 value to the user's own address,
  effectively creating an empty transaction for testing purposes.
  """

  defstruct [:user_address]

  @doc """
  Creates a new EmptySendToSelf transaction.
  
  ## Parameters
  
  - `user_address` - The user's wallet address
  
  ## Returns
  
  A new EmptySendToSelf struct
  
  ## Examples
  
      iex> Miniapp.Transaction.EmptySendToSelf.new("0x1234...")
      %Miniapp.Transaction.EmptySendToSelf{user_address: "0x1234..."}
  """
  def new(user_address) when is_binary(user_address) do
    %__MODULE__{user_address: user_address}
  end

end

defimpl Miniapp.Transaction, for: Miniapp.Transaction.EmptySendToSelf do
  @doc """
  Builds the transaction struct into a calls array for execution.
  
  ## Parameters
  
  - `transaction` - The EmptySendToSelf struct
  
  ## Returns
  
  A list of call maps that can be executed by the transaction lifecycle
  
  ## Examples
  
      iex> transaction = Miniapp.Transaction.EmptySendToSelf.new("0x1234...")
      iex> Miniapp.Transaction.build(transaction)
      [%{"to" => "0x1234..."}]
  """
  def build(%Miniapp.Transaction.EmptySendToSelf{user_address: user_address}) do
    [
      %{"to" => user_address}
    ]
  end
end