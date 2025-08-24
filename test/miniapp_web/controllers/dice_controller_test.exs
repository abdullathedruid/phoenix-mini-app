defmodule MiniappWeb.DiceControllerTest do
  use MiniappWeb.ConnCase

  describe "GET /api/dice" do
    test "returns a dice roll between 1-6", %{conn: conn} do
      conn = get(conn, ~p"/api/dice")
      
      assert response(conn, 200) 
      dice_value = response(conn, 200) |> String.to_integer()
      assert dice_value >= 1 and dice_value <= 6
    end

    test "returns different values on multiple calls", %{conn: conn} do
      # Make multiple calls and collect results
      results = 
        for _ <- 1..10 do
          conn = get(conn, ~p"/api/dice")
          response(conn, 200) |> String.to_integer()
        end

      # Check all results are valid dice values
      assert Enum.all?(results, fn value -> value >= 1 and value <= 6 end)
      
      # With 10 rolls, we should very likely get at least 2 different values
      unique_values = Enum.uniq(results)
      assert length(unique_values) > 1
    end

    test "returns plain text response", %{conn: conn} do
      conn = get(conn, ~p"/api/dice")
      
      response_body = response(conn, 200)
      assert String.match?(response_body, ~r/^\d$/)
    end
  end
end