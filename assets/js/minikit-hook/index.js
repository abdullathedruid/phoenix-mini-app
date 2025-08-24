import { sdk } from "@farcaster/miniapp-sdk";

/**
 * @type {import("phoenix_live_view").Hook}
 */
const WalletHook = {
  async mounted() {
    try {
      await sdk.actions.ready();
      const context = await sdk.context;
      if (context) {
        this.pushEvent("miniapp:connect", { context });
      }
    } catch (error) {
      console.error("MiniApp SDK initialization failed", error);
    }
  }
}
export default WalletHook;