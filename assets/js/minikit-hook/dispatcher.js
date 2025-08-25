import { connect, getAccount, sendCalls, getCapabilities, waitForCallsStatus, getCallsStatus } from "@wagmi/core";

// Recursively convert BigInt values to strings to make payloads JSON-serializable
function sanitizeForJson(value) {
  if (typeof value === "bigint") return value.toString();
  if (Array.isArray(value)) return value.map(sanitizeForJson);
  if (value && typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = sanitizeForJson(v);
    return out;
  }
  return value;
}

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
    const response = await sendCalls(config, params);
    return response;
  },
  async get_capabilities({ config }) {
    const capabilities = await getCapabilities(config);
    return capabilities;
  },
  async wait_for_calls_status({ config, params }) {
    const { id } = params ?? {};
    if (!id) throw new Error("wait_for_calls_status requires id");
    const response = await waitForCallsStatus(config, { id });
    return { response };
  },
  async get_calls_status({ config, params }) {
    const { id } = params ?? {};
    if (!id) throw new Error("get_calls_status requires id");
    const response = await getCallsStatus(config, { id });
    return { response };
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
      const safeResult = sanitizeForJson(result);
      hook.pushEvent("client:response", { id, action, ok: true, result: safeResult });
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


