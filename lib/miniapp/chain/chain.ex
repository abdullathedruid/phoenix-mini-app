defmodule Miniapp.Chain do
  @moduledoc """
  Chain module
  """
  @pubsub Miniapp.PubSub
  @block_topic "chain:block_number"

  @doc """
  Topic for block number broadcasts.
  """
  def block_topic, do: @block_topic

  @doc """
  Broadcast the latest block number to subscribers.
  """
  def broadcast_block_number(block_number) when is_integer(block_number) do
    Phoenix.PubSub.broadcast(@pubsub, @block_topic, {:new_block, block_number})
    :ok
  end

  @doc """
  Subscribe the calling process to block number updates.
  """
  def subscribe_to_blocks do
    Phoenix.PubSub.subscribe(@pubsub, @block_topic)
    :ok
  end
end
