import { sdk } from "@farcaster/miniapp-sdk";
import { createWalletClient, custom } from "viem";
import { base } from "viem/chains";

const walletClient = createWalletClient({
  chain: base,
  transport: custom(window.ethereum),
});

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

    try {
      const provider = await sdk.wallet.getEthereumProvider();
      if (provider) {
        this.pushEvent("miniapp:provider", { provider });
      }
    } catch (error) {
      console.error("Failed to get Ethereum provider", error);
    }

    try {
      const block = await window.publicClient.getBlockNumber();
      this.pushEvent("miniapp:block", { blockNumber: block });
    } catch (error) {
      console.error("Failed to get block number", error);
    }

    try {
      const account = await walletClient.getAddresses();
      this.pushEvent("miniapp:account", { account: account[0] });
    } catch (error) {
      console.error("Failed to get account", error);
    }
  }
}
export default WalletHook;