defmodule Miniapp.ChainTest do
  use ExUnit.Case, async: true

  alias Miniapp.Chain

  describe "broadcast_block_number/1" do
    test "broadcasts block number to subscribers" do
      # Subscribe to block updates
      :ok = Chain.subscribe_to_blocks()
      
      # Broadcast a block number
      :ok = Chain.broadcast_block_number(123_456)
      
      # Should receive the broadcast
      assert_receive {:new_block, 123_456}, 100
    end

    test "accepts integer block numbers" do
      assert :ok = Chain.broadcast_block_number(1)
      assert :ok = Chain.broadcast_block_number(999_999)
    end
  end

  describe "subscribe_to_blocks/0" do
    test "returns :ok when subscribing" do
      assert :ok = Chain.subscribe_to_blocks()
    end

    test "allows multiple subscriptions" do
      assert :ok = Chain.subscribe_to_blocks()
      assert :ok = Chain.subscribe_to_blocks()
    end
  end

  describe "block_topic/0" do
    test "returns the block topic string" do
      assert is_binary(Chain.block_topic())
      assert String.contains?(Chain.block_topic(), "chain")
      assert String.contains?(Chain.block_topic(), "block")
    end
  end
end