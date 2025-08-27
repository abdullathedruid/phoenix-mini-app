# Miniapp

A Phoenix LiveView application that provides a Farcaster mini-app interface for blockchain transaction management on Base. The app demonstrates real-time transaction orchestration between Elixir GenStatem processes and JavaScript wallet interactions over Phoenix channels.

## Architecture Overview

### Transaction Flow

The application implements a sophisticated transaction lifecycle using Elixir's GenStatem behavior to manage state transitions:

1. **Transaction Request**: User initiates transaction via LiveView interface
2. **State Management**: `Transaction.Lifecycle` GenStatem handles state transitions (building → requested → waiting)
3. **Elixir-JS Bridge**: Real-time communication over Phoenix LiveView socket using `push_event/2` and `handle_event/3`
4. **Wallet Integration**: JavaScript hooks dispatch wallet operations via Farcaster MiniApp SDK and Wagmi
5. **Response Handling**: Asynchronous responses flow back through the socket to update transaction state

### Key Components

- **`MiniappWeb.WalletLive`**: LiveView controller managing wallet connectivity and transaction UI
- **`Miniapp.Transaction.Lifecycle`**: GenStatem implementing transaction state machine
- **`assets/js/minikit-hook/`**: JavaScript bridge handling wallet operations and SDK integration
- **`Miniapp.Client.Dispatcher`**: Event dispatcher for coordinating transaction requests
- **`Miniapp.Transaction.Manager`**: Supervisor for transaction lifecycle processes

### Elixir-JS Communication Pattern

```elixir
# Elixir -> JavaScript
socket |> push_event("client:request", %{action: "send_calls", data: calls})

# JavaScript -> Elixir
this.pushEvent("client:response", {action: "send_calls", id: transaction_id})
```

The bridge uses Phoenix LiveView's bidirectional event system to coordinate between:
- Elixir GenStatem processes managing transaction state
- JavaScript wallet operations (connect, send_calls, wait_for_calls_status)
- Real-time UI updates reflecting transaction progress

## Development Setup

```bash
# Install dependencies
mix setup

# Start Phoenix server
mix phx.server

# Visit http://localhost:4000
```

## Observability

The application includes comprehensive monitoring:
- **Prometheus**: Metrics collection with custom transaction plugins
- **Grafana**: Dashboards for application and BEAM VM metrics
- **OpenTelemetry**: Distributed tracing for transaction flows
- **Docker Compose**: Local observability stack via `docker-compose-o11y.yml`

## Testing

```bash
# Run test suite
mix test

# With coverage
mix test --cover
```
