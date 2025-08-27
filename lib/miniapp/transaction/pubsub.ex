defmodule Miniapp.Transaction.Pubsub do
  @pubsub Miniapp.PubSub
  @transaction_events_topic "transaction_events"

  def pubsub, do: @pubsub

  def transaction_events_topic(user_address),
    do: "#{@transaction_events_topic}:#{String.downcase(user_address)}"

  def subscribe_to_events(user_address) do
    Phoenix.PubSub.subscribe(@pubsub, transaction_events_topic(user_address))
    :ok
  end

  def broadcast_event(event, user_address) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      transaction_events_topic(user_address),
      {:transaction_event, event}
    )

    :ok
  end
end
