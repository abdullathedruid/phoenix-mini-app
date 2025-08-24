import { connect, getAccount, sendCalls, getCapabilities } from "@wagmi/core";

// Default action handlers. Extend this object with new client-side actions.
export const actionHandlers = {
  async get_account({ config }) {
    const { address } = getAccount(config);
    return { address };
  },
  async connect_account({ config }) {
    const { accounts } = await connect(config, { connector: config.connectors[0] });
    return { accounts };
  },
  async send_calls({ config, params }) {
    const calls = params?.calls || [];
    const { id } = await sendCalls(config, { calls });
    return { id };
  },
  async get_capabilities({ config }) {
    const capabilities = await getCapabilities(config);
    return capabilities;
  },
};

// Creates a handler function suitable for LV `handleEvent("client:request", handler)`
// deps: { config, sdk, hook }
export function createClientRequestHandler(deps) {
  const { config, sdk, hook, handlers = actionHandlers } = deps;

  return async function handleClientRequest({ id = null, action, params }) {
    try {
      const handler = handlers[action];
      if (!handler) {
        throw new Error(`Unknown action: ${action}`);
      }
      const result = await handler({ config, sdk, hook, params });
      hook.pushEvent("client:response", { id, action, ok: true, result });
    } catch (error) {
      hook.pushEvent("client:response", {
        id,
        action,
        ok: false,
        error: error?.message || String(error),
      });
    }
  };
}


