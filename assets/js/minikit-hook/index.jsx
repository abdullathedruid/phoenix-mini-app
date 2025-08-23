import React from "react";
import { createRoot } from "react-dom/client";
import {MiniKitProvider} from "@coinbase/onchainkit/minikit"
import App from "./App"

/**
 * @type {import("phoenix_live_view").Hook}
 */
const WalletHook = {
  mounted() {
    const root = createRoot(this.el)
    root.render(
      <MiniKitProvider>
        <App pushEvent={(event, payload, onReply) => this.pushEvent(event, payload, onReply)} />
      </MiniKitProvider>
    )
  }
}
export default WalletHook;