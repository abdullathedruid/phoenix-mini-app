import { sdk } from "@farcaster/miniapp-sdk";
import { http, createConfig } from "@wagmi/core";
import { baseSepolia } from "@wagmi/core/chains";
import { farcasterMiniApp as miniAppConnector } from "@farcaster/miniapp-wagmi-connector";
import { createClientRequestHandler } from "./dispatcher";

const config = createConfig({
  connectors: [miniAppConnector()],
  transports: {
    [baseSepolia.id]: http(),
  },
  chains: [baseSepolia],
});

/**
 * @type {import("phoenix_live_view").Hook}
 */
const WalletHook = {
  async sendContextToServer() {
    try {
      await sdk.actions.ready();
      const context = await sdk.context;
      if (context) {
        this.pushEvent("miniapp:connect", { context });
      }
    } catch (error) {
      console.error("Failed to send context to server", error);
    }
  },
  async mounted() {
    await this.sendContextToServer();
    this.handleEvent("client:request", createClientRequestHandler({ config, sdk, hook: this }));
  },

  async reconnected() {
    await this.sendContextToServer();
  },
}
export default WalletHook;