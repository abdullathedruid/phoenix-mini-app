import React, { useEffect } from "react";
import { useMiniKit } from "@coinbase/onchainkit/minikit";

export default function App({ pushEvent }) {
  const { isFrameReady, setFrameReady } = useMiniKit();

  useEffect(() => {
    console.log("isFrameReady", isFrameReady)
    if (!isFrameReady) {
      console.log("setting frame ready")
      setFrameReady();
    }
  }, [setFrameReady, isFrameReady])

  return <div>
    <button onClick={() => pushEvent("wallet:connect")}>Connect Wallet</button>
  </div>
}