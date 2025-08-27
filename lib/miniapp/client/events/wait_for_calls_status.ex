defmodule Miniapp.Client.Events.WaitForCallsStatus do
  @enforce_keys [:id]
  defstruct id: nil

  @type t :: %__MODULE__{
          id: String.t()
        }

  def params(%__MODULE__{} = event) do
    %{"id" => event.id}
  end
end

defmodule Miniapp.Client.Events.WaitForCallsStatusResponse do
  @enforce_keys [:id]
  defstruct id: nil

  @type t :: %__MODULE__{
          id: String.t()
        }
end
