import React from "react";
import { createRoot } from "react-dom/client";
import {MiniKitProvider} from "@coinbase/onchainkit/minikit"
import App from "./App"

/**
 * @type {import("phoenix_live_view").Hook}
 */
const WalletHook = {
  mounted() {
    console.log("mounted")
    const root = createRoot(this.el)
    root.render(
      <MiniKitProvider>
        <App pushEvent={this.pushEvent} />
      </MiniKitProvider>
    )
  }
}
export default WalletHook;