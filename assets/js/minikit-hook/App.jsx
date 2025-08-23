import React, { useEffect } from "react";
import { useMiniKit } from "@coinbase/onchainkit/minikit";

/**
 * pushEvent signature from Phoenix LiveView hooks.
 *
 * - pushEvent(event, payload?) => Promise<any>
 * - pushEvent(event, payload, onReply) => void
 *
 * @callback PushEvent
 * @param {string} event
 * @param {any} [payload]
 * @param {(reply: any, ref: number) => any} [onReply]
 * @returns {Promise<any>|void}
 */

/**
 * @param {{ pushEvent: PushEvent }} props
 */
export default function App({ pushEvent }) {
  const { context, isFrameReady, setFrameReady } = useMiniKit();

  useEffect(() => {
    if (!isFrameReady) {
      setFrameReady();
    }
  }, [setFrameReady, isFrameReady])

  useEffect(() => {
    if (context) {
      pushEvent("wallet:connect", {context: context})
    }
  }, [context])

  return <div>
    <button onClick={() => pushEvent("wallet:connect")}>Connect Wallet</button>
  </div>
}