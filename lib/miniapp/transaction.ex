defprotocol Miniapp.Transaction do
  @moduledoc """
  Protocol for building transaction calls from transaction structs.
  
  Each transaction type should implement this protocol to convert
  its struct representation into a calls array that can be executed
  by the transaction lifecycle.
  """

  @doc """
  Builds the transaction struct into a calls array for execution.
  
  ## Parameters
  
  - `transaction` - The transaction struct implementing this protocol
  
  ## Returns
  
  A list of call maps that can be executed by the transaction lifecycle
  """
  @spec build(t) :: [map()]
  def build(transaction)
end