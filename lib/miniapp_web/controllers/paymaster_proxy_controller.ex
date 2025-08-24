defmodule MiniappWeb.PaymasterProxyController do
  use MiniappWeb, :controller

  @doc """
  Proxies any request under /api/paymaster/*path to the configured PAYMASTER_URL,
  preserving method, headers (with a safe allowlist), query string and JSON body.
  """
  def proxy(conn, %{"path" => path_segments}) do
    with {:ok, target_url} <- build_target_url(path_segments, conn.query_string),
         {:ok, req_method} <- normalize_method(conn.method),
         {:ok, headers} <- build_headers(conn) do
      request_opts = [
        method: req_method,
        url: target_url,
        headers: headers
      ]

      request_opts =
        case conn.body_params do
          %{} = params when map_size(params) > 0 -> Keyword.put(request_opts, :json, params)
          _ -> request_opts
        end

      case Req.request(request_opts) do
        {:ok, %Req.Response{status: status, body: body}} ->
          respond(conn, status, body)

        {:error, %Req.TransportError{} = error} ->
          conn
          |> put_status(502)
          |> json(%{error: "Bad Gateway", reason: Exception.message(error)})

        {:error, error} ->
          conn
          |> put_status(500)
          |> json(%{error: "Proxy Error", reason: Exception.message(error)})
      end
    else
      {:error, :no_upstream} ->
        conn
        |> put_status(500)
        |> json(%{error: "PAYMASTER_URL not configured"})

      {:error, :bad_method} ->
        conn
        |> put_status(405)
        |> json(%{error: "Method Not Allowed"})
    end
  end

  defp build_target_url(path_segments, query_string) do
    case System.get_env("PAYMASTER_URL") || get_config(:url) do
      nil -> {:error, :no_upstream}
      base_url ->
        base = URI.parse(base_url)
        joined_path = Enum.join(path_segments || [], "/")
        base_path = base.path || "/"
        full_path = Path.join(base_path, joined_path)
        url = %{base | path: full_path, query: query_string}
        {:ok, URI.to_string(url)}
    end
  end

  defp normalize_method(method) when is_binary(method) do
    method
    |> String.downcase()
    |> String.to_existing_atom()
    |> then(&{:ok, &1})
  rescue
    ArgumentError -> {:error, :bad_method}
  end

  # Build a safe set of headers to forward
  defp build_headers(conn) do
    forward_header_names = MapSet.new([
      "accept",
      "content-type",
      "user-agent",
      "accept-language",
      "accept-encoding",
      "authorization",
      "x-request-id"
    ])

    forwarded =
      conn.req_headers
      |> Enum.filter(fn {name, _} -> MapSet.member?(forward_header_names, String.downcase(name)) end)

    {:ok, forwarded}
  end

  defp respond(conn, status, body) when is_map(body) or is_list(body) do
    conn |> put_status(status) |> json(body)
  end

  defp respond(conn, status, body) when is_binary(body) do
    send_resp(conn, status, body)
  end

  defp respond(conn, status, body) do
    conn |> put_status(status) |> json(%{result: body})
  end

  defp get_config(key) do
    case Application.get_env(:miniapp, __MODULE__) do
      nil -> nil
      kw when is_list(kw) -> Keyword.get(kw, key)
      _ -> nil
    end
  end
end
