import { sdk } from "@farcaster/miniapp-sdk";
import { http, createConfig, getAccount } from "@wagmi/core";
import { base } from "@wagmi/core/chains";
import { farcasterMiniApp as miniAppConnector } from "@farcaster/miniapp-wagmi-connector";

const config = createConfig({
  connectors: [miniAppConnector()],
  transports: {
    [base.id]: http(),
  },
  chains: [base],
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

    this.handleEvent("hello", (params) => {
      console.log("hello", params);
    });

    try {
      const { address } = getAccount(config);
      this.pushEvent("miniapp:accounts", { address });
    } catch (error) {
      console.error("Failed to get account", error);
    }
  },

  async reconnected() {
    await this.sendContextToServer();
  },
}
export default WalletHook;