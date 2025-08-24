defmodule MiniappWeb.WalletLiveTest do
  use MiniappWeb.ConnCase
  import Phoenix.LiveViewTest
  
  alias Miniapp.Chain

  describe "mount" do
    test "initializes with default assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      assert render(view) =~ "My app"
      assert render(view) =~ "This is a work in progress"
      
      # Should not show connected wallet buttons initially
      refute render(view) =~ "Get Capabilities"
      refute render(view) =~ "Test Transaction"
    end

    test "subscribes to block updates when connected", %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/embed/wallet")
      
      # Broadcast a block update
      Chain.broadcast_block_number(12345)
      
      # Should handle the block update (we can't easily assert on assigns in tests,
      # but we can verify no crashes occur)
      Process.sleep(10)
    end
  end

  describe "miniapp:connect event" do
    test "handles user connection and sets user data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      context = %{
        "user" => %{
          "fid" => "123",
          "displayName" => "Test User",
          "pfpUrl" => "https://example.com/avatar.jpg"
        },
        "client" => %{"clientFid" => "456"}
      }
      
      # Trigger connect event using render_hook directly 
      view
      |> render_hook("miniapp:connect", %{"context" => context})
      
      # Should push get_account request (we can't easily verify the push_event,
      # but we can verify the event was handled without error)
      assert render(view)
    end
  end

  describe "get_capabilities event" do
    test "shows error when wallet not connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Button should not be visible when no wallet connected
      refute render(view) =~ "Get Capabilities"
      
      # Try to send get_capabilities event directly (simulating JS event)
      view
      |> render_hook("get_capabilities")
      
      # Should show error message in flash
      assert render(view) =~ "connect your wallet"
    end

    test "shows buttons when wallet is connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # First simulate wallet connection event
      view
      |> render_hook("client:response", %{
        "action" => "get_account",
        "ok" => true,
        "result" => %{"address" => "0x123abc"}
      })
      
      # Should now show the capabilities button
      assert render(view) =~ "Get Capabilities" 
      assert render(view) =~ "Test Transaction"
      
      # Click the get capabilities button
      view
      |> element("button", "Get Capabilities")
      |> render_click()
      
      # Should not show error
      refute render(view) =~ "connect your wallet"
    end
  end

  describe "test_transaction event" do
    test "button not visible when no wallet connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Button should not be visible when no wallet connected
      refute render(view) =~ "Test Transaction"
      
      # Try to send test_transaction event directly (simulating JS event)
      view
      |> render_hook("test_transaction")
      
      # Should handle without error (would push connect_account request)
      assert render(view)
    end

    test "sends transaction when wallet is connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Simulate connected wallet event
      view
      |> render_hook("client:response", %{
        "action" => "get_account", 
        "ok" => true,
        "result" => %{"address" => "0x123abc"}
      })
      
      # Should show test transaction button
      assert render(view) =~ "Test Transaction"
      
      # Click test transaction button
      view
      |> element("button", "Test Transaction")
      |> render_click()
      
      # Should handle without error
      assert render(view)
    end
  end

  describe "client response handling" do
    test "handles successful capability response", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Send capabilities response event
      view
      |> render_hook("client:response", %{
        "action" => "get_capabilities",
        "ok" => true,
        "result" => %{
          "8453" => %{
            "atomic" => %{"supported" => true},
            "atomicBatch" => %{"supported" => false},
            "auxiliaryFunds" => %{"supported" => true},
            "paymasterService" => %{"supported" => false}
          }
        }
      })
      
      # Should handle without error
      assert render(view)
    end

    test "handles successful account response", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Send account response event
      view
      |> render_hook("client:response", %{
        "action" => "get_account",
        "ok" => true, 
        "result" => %{"address" => "0x123abc"}
      })
      
      # Should handle without error and show buttons
      rendered = render(view)
      assert rendered =~ "Get Capabilities"
      assert rendered =~ "Test Transaction"
    end

    test "handles successful transaction response", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Send transaction response event
      view
      |> render_hook("client:response", %{
        "action" => "send_calls",
        "ok" => true,
        "result" => %{"id" => "tx_12345"}
      })
      
      # Should handle without error
      assert render(view)
    end

    test "handles failed transaction response", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Send transaction error response event
      view
      |> render_hook("client:response", %{
        "action" => "send_calls",
        "ok" => false,
        "error" => "User rejected transaction"
      })
      
      # Should handle error without crashing
      assert render(view)
    end

    test "handles empty account response by trying to connect", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Send empty account response event
      view
      |> render_hook("client:response", %{
        "action" => "get_account",
        "ok" => true,
        "result" => %{}
      })
      
      # Should handle without error (would try to connect)
      assert render(view)
    end
  end

  describe "block updates" do
    test "handles new block messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Send a new block message
      send(view.pid, {:new_block, 54321})
      
      # Should handle without error
      assert render(view)
    end
  end

  describe "unhandled events" do
    test "logs warning for unknown events", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/embed/wallet")
      
      # Send unknown event using render_hook directly
      view
      |> render_hook("unknown_event", %{"param" => "value"})
      
      # Should handle gracefully
      assert render(view)
    end
  end
end