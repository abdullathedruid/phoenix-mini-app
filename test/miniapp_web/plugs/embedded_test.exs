defmodule MiniappWeb.Plugs.EmbeddedTest do
  use MiniappWeb.ConnCase, async: true
  
  alias MiniappWeb.Plugs.Embedded

  describe "init/1" do
    test "returns the passed options" do
      opts = %{test: "value"}
      assert Embedded.init(opts) == opts
    end
  end

  describe "call/2" do
    test "sets content security policy header" do
      conn = build_conn() |> Embedded.call([])
      
      csp_header = get_resp_header(conn, "content-security-policy")
      assert length(csp_header) == 1
      
      csp = List.first(csp_header)
      assert String.contains?(csp, "default-src 'self'")
      assert String.contains?(csp, "frame-ancestors *")
      assert String.contains?(csp, "script-src 'self'")
      assert String.contains?(csp, "style-src 'self' 'unsafe-inline'")
      assert String.contains?(csp, "img-src 'self' data: https:")
    end

    test "removes x-frame-options header" do
      conn = 
        build_conn()
        |> put_resp_header("x-frame-options", "DENY")
        |> Embedded.call([])
      
      x_frame_header = get_resp_header(conn, "x-frame-options")
      assert x_frame_header == []
    end

    test "allows iframe embedding by removing x-frame-options" do
      conn = 
        build_conn()
        |> put_resp_header("x-frame-options", "SAMEORIGIN")
        |> Embedded.call([])
      
      # Should not have x-frame-options header
      assert get_resp_header(conn, "x-frame-options") == []
      
      # Should have frame-ancestors policy allowing all origins
      csp = get_resp_header(conn, "content-security-policy") |> List.first()
      assert String.contains?(csp, "frame-ancestors *")
    end

    test "preserves other headers" do
      conn = 
        build_conn()
        |> put_resp_header("custom-header", "test-value")
        |> Embedded.call([])
      
      assert get_resp_header(conn, "custom-header") == ["test-value"]
    end
  end
end