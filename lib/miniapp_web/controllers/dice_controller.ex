defmodule MiniappWeb.DiceController do
  use MiniappWeb, :controller
  require OpenTelemetry.Tracer, as: Tracer
  require Logger

  def roll(conn, _params) do
    send_resp(conn, 200, roll_dice())
  end

  defp roll_dice do
    Tracer.with_span "roll_dice" do
      Logger.info("Rolling dice")
      roll = Enum.random(1..6)
      Logger.info("Rolled a #{roll}")

      Tracer.set_attribute("roll", roll)

      to_string(roll)
    end
  end
end
