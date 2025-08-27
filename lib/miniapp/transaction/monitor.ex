defmodule Miniapp.Transaction.Monitor do
  @moduledoc """
  Monitors transaction system health and metrics
  """
  require Logger
  alias OpenTelemetry.Span
  @tracer_id __MODULE__

  def setup(opts \\ []) do
    attach_handlers(opts)
  end

  def execute(event, measurements, meta) when is_list(event) do
    base_measurements = %{
      system_time: System.system_time(),
      monotonic_time: System.monotonic_time()
    }

    :telemetry.execute([:transaction] ++ event, Map.merge(base_measurements, measurements), meta)
  end

  def execute(event, measurements, meta) when is_atom(event) do
    base_measurements = %{
      system_time: System.system_time(),
      monotonic_time: System.monotonic_time()
    }

    :telemetry.execute(
      [:transaction] ++ [event],
      Map.merge(base_measurements, measurements),
      meta
    )
  end

  defp attach_handlers(_opts) do
    :telemetry.attach_many(
      {__MODULE__, :transaction_monitor},
      [
        [:transaction, :started],
        [:transaction, :ended],
        [:transaction, :building, :started],
        [:transaction, :building, :ended],
        [:transaction, :requested, :started],
        [:transaction, :requested, :ended],
        [:transaction, :waiting_for_calls_status, :started],
        [:transaction, :waiting_for_calls_status, :ended]
      ],
      &__MODULE__.handle_telemetry_event/4,
      %{}
    )
  end

  def handle_telemetry_event(event, measurements, meta, config) do
    Logger.info(
      "Telemetry event #{inspect(event)} #{inspect(measurements)} #{inspect(meta)} #{inspect(config)}"
    )

    :ok
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

  def handle_telemetry_event([:transaction, ended], measurements, meta, config)
      when ended in [:completed, :failed] do
    dbg()
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Span.set_attribute(ctx, :duration_ms, duration_ms)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end

  def handle_telemetry_event([:transaction, :broadcasted], _measurements, meta, _config) do
    dbg()
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)
    Span.add_event(ctx, "transaction-broadcasted", %{})
  end
end
