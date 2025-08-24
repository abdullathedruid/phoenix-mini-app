defmodule Miniapp.Wallet.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias Miniapp.Wallet.Capabilities

  describe "parse/1" do
    test "parses supported atomic status" do
      input = %{
        "8453" => %{"atomic" => %{"status" => "supported"},
          "auxiliaryFunds" => %{"supported" => true},
          "paymasterService" => %{"supported" => true}}
      }

      assert %{
               atomic_status: :supported,
               auxiliary_funds: true,
               paymaster_service: true
             } = Capabilities.parse(input)
    end

    test "parses ready atomic status" do
      input = %{
        "8453" => %{"atomic" => %{"status" => "ready"},
          "auxiliaryFunds" => %{"supported" => false},
          "paymasterService" => %{"supported" => false}}
      }

      assert %{
               atomic_status: :ready,
               auxiliary_funds: false,
               paymaster_service: false
             } = Capabilities.parse(input)
    end

    test "defaults to unsupported when unknown or missing status" do
      input = %{
        "8453" => %{"atomic" => %{"status" => "unknown"},
          "auxiliaryFunds" => %{"supported" => false},
          "paymasterService" => %{"supported" => false}}
      }

      assert %{
               atomic_status: :unsupported,
               auxiliary_funds: false,
               paymaster_service: false
             } = Capabilities.parse(input)

      # Missing atomic key entirely also defaults to unsupported
      input2 = %{
        "8453" => %{"auxiliaryFunds" => %{"supported" => false},
          "paymasterService" => %{"supported" => false}}
      }

      assert %{
               atomic_status: :unsupported,
               auxiliary_funds: false,
               paymaster_service: false
             } = Capabilities.parse(input2)
    end

    test "treats boolean or string true as supported flags" do
      input_bool_true = %{
        "8453" => %{"atomic" => %{"status" => "supported"},
          "auxiliaryFunds" => %{"supported" => true},
          "paymasterService" => %{"supported" => true}}
      }

      assert %{auxiliary_funds: true, paymaster_service: true} =
               Capabilities.parse(input_bool_true)

      input_string_true = %{
        "8453" => %{"atomic" => %{"status" => "supported"},
          "auxiliaryFunds" => %{"supported" => "true"},
          "paymasterService" => %{"supported" => "true"}}
      }

      assert %{auxiliary_funds: true, paymaster_service: true} =
               Capabilities.parse(input_string_true)
    end

    test "handles completely invalid input by returning defaults" do
      assert %{
               atomic_status: :unsupported,
               auxiliary_funds: false,
               paymaster_service: false
             } = Capabilities.parse(%{})

      assert %{
               atomic_status: :unsupported,
               auxiliary_funds: false,
               paymaster_service: false
             } = Capabilities.parse(nil)

      assert %{
               atomic_status: :unsupported,
               auxiliary_funds: false,
               paymaster_service: false
             } = Capabilities.parse("not a map")
    end
  end
end
