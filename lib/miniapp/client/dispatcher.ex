defmodule Miniapp.Client.Dispatcher do
  alias Miniapp.Client.Event

  def build_request(event, opts \\ []) do
    id = Keyword.get(opts, :id)
    action = Event.action(event)
    %{"action" => action, "id" => id, "params" => Event.params(event)}
  end
end
