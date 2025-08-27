defmodule Miniapp.Client.Event do
  alias Miniapp.Client.Events

  @registry_by_action %{
    "send_calls" => Events.SendCalls,
    "wait_for_calls_status" => Events.WaitForCallsStatus
  }

  @registry_by_event @registry_by_action
                     |> Enum.map(fn {action, module} -> {module, action} end)
                     |> Map.new()

  def get_module_by_action(action) do
    @registry_by_action[action]
  end

  def get_action_by_module(%module{}) do
    @registry_by_event[module]
  end

  def action(event), do: get_action_by_module(event)

  def params(%module{} = event), do: module.params(event)
end
