import assert from "node:assert/strict";

const url = process.env.MCP_URL || "http://127.0.0.1:8787/mcp";
const version = "2026-07-28";
let nextId = 1;

async function request(method, params = {}, options = {}) {
  const id = nextId++;
  const body = {
    jsonrpc: "2.0",
    id,
    method,
    params: {
      ...params,
      _meta: {
        "io.modelcontextprotocol/protocolVersion": options.version || version,
        "io.modelcontextprotocol/clientCapabilities": {},
      },
    },
  };
  const headers = {
    "Content-Type": "application/json",
    Accept: "application/json, text/event-stream",
    "MCP-Protocol-Version": options.version || version,
    "Mcp-Method": options.headerMethod || method,
  };
  if (params.name || params.uri) headers["Mcp-Name"] = params.name || params.uri;
  if (options.origin) headers.Origin = options.origin;
  const response = await fetch(url, { method: "POST", headers, body: JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
}

const discovery = await request("server/discover");
assert.equal(discovery.status, 200);
assert.deepEqual(discovery.body.result.supportedVersions, [version]);
assert.deepEqual(Object.keys(discovery.body.result.capabilities).sort(), ["resources", "tools"]);

const tools = await request("tools/list");
assert.equal(tools.status, 200);
assert.deepEqual(tools.body.result.tools.map((tool) => tool.name), ["ask_ai", "hello"]);
assert.deepEqual(tools.body.result.tools[0].inputSchema.required, ["question"]);
assert.deepEqual(tools.body.result.tools[1].inputSchema.required, ["name"]);

const greeting = await request("tools/call", { name: "hello", arguments: { name: "PicoRuby" } });
assert.equal(greeting.status, 200);
assert.equal(greeting.body.result.content[0].text, "Hello, PicoRuby!");

const shouted = await request("tools/call", { name: "hello", arguments: { name: "PicoRuby", shout: true } });
assert.equal(shouted.body.result.content[0].text, "HELLO, PICORUBY!");

const missing = await request("tools/call", { name: "hello", arguments: {} });
assert.equal(missing.status, 400);
assert.equal(missing.body.error.code, -32602);

const mismatch = await request("tools/list", {}, { headerMethod: "tools/call" });
assert.equal(mismatch.status, 400);
assert.equal(mismatch.body.error.code, -32020);

const unsupported = await request("server/discover", {}, { version: "1900-01-01" });
assert.equal(unsupported.status, 400);
assert.equal(unsupported.body.error.code, -32022);

const resources = await request("resources/list");
assert.equal(resources.status, 200);
assert.equal(resources.body.result.resources[0].uri, "demo://about");

const about = await request("resources/read", { uri: "demo://about" });
assert.equal(about.status, 200);
assert.match(about.body.result.contents[0].text, /PicoRuby MCP server/);

const blockedOrigin = await request("tools/list", {}, { origin: "https://example.com" });
assert.equal(blockedOrigin.status, 403);

const legacyInit = await fetch(url, {
  method: "POST",
  headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
  body: JSON.stringify({
    jsonrpc: "2.0",
    id: nextId++,
    method: "initialize",
    params: {
      protocolVersion: "2025-11-25",
      capabilities: {},
      clientInfo: { name: "smoke-test", version: "1.0.0" },
    },
  }),
});
assert.equal(legacyInit.status, 200);
assert.equal((await legacyInit.json()).result.protocolVersion, "2025-11-25");

const legacyReady = await fetch(url, {
  method: "POST",
  headers: { "Content-Type": "application/json", "MCP-Protocol-Version": "2025-11-25" },
  body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
});
assert.equal(legacyReady.status, 202);

const legacyTools = await fetch(url, {
  method: "POST",
  headers: { "Content-Type": "application/json", "MCP-Protocol-Version": "2025-11-25" },
  body: JSON.stringify({ jsonrpc: "2.0", id: nextId++, method: "tools/list", params: {} }),
});
assert.equal(legacyTools.status, 200);
const legacyList = (await legacyTools.json()).result;
assert.equal(legacyList.tools[0].name, "ask_ai");
assert.equal("resultType" in legacyList, false);

const legacyCall = await fetch(url, {
  method: "POST",
  headers: { "Content-Type": "application/json", "MCP-Protocol-Version": "2025-11-25" },
  body: JSON.stringify({
    jsonrpc: "2.0",
    id: nextId++,
    method: "tools/call",
    params: { name: "hello", arguments: { name: "Codex" } },
  }),
});
assert.equal(legacyCall.status, 200);
assert.equal((await legacyCall.json()).result.content[0].text, "Hello, Codex!");

console.log("MCP dev smoke test passed");
