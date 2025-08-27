defmodule Miniapp.PromEx.TxPlugin do
  use PromEx.Plugin

  import Telemetry.Metrics

  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :transaction_metrics,
        [
          distribution(
            "miniapp_transaction_total_duration_ms",
            event_name: [:transaction, :parent, :ended],
            measurement: :duration_ms,
            tags: [:status],
            reporter_options: [buckets: [250, 500, 1000, 2000, 5000, 10_000, 30_000]]
          ),
          distribution(
            "miniapp_transaction_building_duration_ms",
            event_name: [:transaction, :building, :ended],
            measurement: :duration_ms,
            tags: [:status],
            reporter_options: [buckets: [250, 500, 1000, 2000, 5000, 10_000, 30_000]]
          ),
          distribution(
            "miniapp_transaction_requested_duration_ms",
            event_name: [:transaction, :requested, :ended],
            measurement: :duration_ms,
            tags: [:status],
            reporter_options: [buckets: [250, 500, 1000, 2000, 5000, 10_000, 30_000]]
          ),
          distribution(
            "miniapp_transaction_waiting_for_calls_status_duration_ms",
            event_name: [:transaction, :waiting_for_calls_status, :ended],
            measurement: :duration_ms,
            tags: [:status],
            reporter_options: [buckets: [250, 500, 1000, 2000, 5000, 10_000, 30_000]]
          ),
          counter(
            "miniapp_transaction_total_count",
            event_name: [:transaction, :parent, :ended],
            tags: [:status]
          )
        ]
      )
    ]
  end
end
