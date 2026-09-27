import { createWorker } from "../generated/worker/runtime/index.js";
import app from "../generated/worker/app.bin";
import { cloudflareBindingTypes } from "../generated/worker/bindings.js";

const afterRequest = async (request, _env, _ctx, _rackEnv, response) => {
  if (request.method === "POST" && new URL(request.url).pathname === "/mcp" && response.status >= 400) {
    console.error("MCP response", response.status, await response.clone().text());
  }
  return response;
};

export default createWorker({
  app,
  bindingTypes: cloudflareBindingTypes,
  afterRequest,
});
