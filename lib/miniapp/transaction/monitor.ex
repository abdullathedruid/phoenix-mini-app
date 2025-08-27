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
        [:transaction, :parent, :started],
        [:transaction, :parent, :ended],
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

  def handle_telemetry_event([_, _, :started] = event, measurements, meta, config) do
    Logger.info(
      "Telemetry event #{inspect(event)} #{inspect(measurements)} #{inspect(meta)} #{inspect(config)}"
    )

    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      get_span_name(event, meta),
      meta,
      %{}
    )
    |> Span.set_attributes(%{
      user_address: meta.user_address,
      transaction_id: meta.transaction_id
    })

    :ok
  end

  def handle_telemetry_event([_, _, :ended] = event, measurements, meta, config) do
    Logger.info(
      "Telemetry event #{inspect(event)} #{inspect(measurements)} #{inspect(meta)} #{inspect(config)}"
    )

    attributes =
      if Map.has_key?(meta, :reason) do
        %{status: inspect(meta.reason)}
      else
        %{status: "success"}
      end
      |> Map.merge(%{user_address: meta.user_address, transaction_id: meta.transaction_id})

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, attributes)
  end

  defp get_span_name([_, state, :started], _meta) do
    "transaction.#{state}"
  end
end
