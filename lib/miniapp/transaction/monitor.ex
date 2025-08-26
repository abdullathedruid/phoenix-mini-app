defmodule Miniapp.Transaction.Monitor do
  @moduledoc """
  Monitors transaction system health and metrics
  """
  alias OpenTelemetry.Span
  @tracer_id __MODULE__

  def setup(opts \\ []) do
    attach_handlers(opts)
  end

  defp attach_handlers(_opts) do
    :telemetry.attach_many(
      {__MODULE__, :transaction_monitor},
      [
        [:transaction, :started],
        [:transaction, :broadcasted],
        [:transaction, :completed],
        [:transaction, :failed]
      ],
      &__MODULE__.handle_telemetry_event/4,
      %{}
    )
  end

  def handle_telemetry_event([:transaction, :started], _measurements, meta, _config) do
  dbg()
    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      "transaction",
      meta,
      %{}
    )
  end

  def handle_telemetry_event([:transaction, ended], measurements, meta, config) when ended in [:completed, :failed] do
  dbg()
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Span.set_attribute(ctx, :duration_ms, duration_ms)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end

  def handle_telemetry_event([:transaction, :broadcasted], _measurements, meta, _config) do
  dbg()
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)
  Span.add_event(ctx,"transaction-broadcasted", %{})
  end
end
