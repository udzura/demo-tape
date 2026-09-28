import assert from "node:assert/strict";

const url = process.env.MCP_URL || "http://127.0.0.1:8787/mcp";
const response = await fetch(url, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json, text/event-stream",
    "MCP-Protocol-Version": "2026-07-28",
    "Mcp-Method": "tools/call",
    "Mcp-Name": "slow_progress",
  },
  body: JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: {
      name: "slow_progress",
      arguments: {},
      _meta: {
        "io.modelcontextprotocol/protocolVersion": "2026-07-28",
        "io.modelcontextprotocol/clientCapabilities": {},
        progressToken: "slow-progress-test",
      },
    },
  }),
  signal: AbortSignal.timeout(30_000),
});

assert.equal(response.status, 200);
assert.equal(response.headers.get("content-type"), "text/event-stream");
const events = [];
const reader = response.body.getReader();
const decoder = new TextDecoder();
let pending = "";
while (true) {
  const { value, done } = await reader.read();
  pending += decoder.decode(value, { stream: !done });
  let boundary;
  while ((boundary = pending.indexOf("\n\n")) >= 0) {
    const frame = pending.slice(0, boundary);
    pending = pending.slice(boundary + 2);
    assert.ok(frame.startsWith("data: "));
    const event = JSON.parse(frame.slice(6));
    events.push(event);
    if (event.method === "notifications/progress") {
      console.log(`${event.params.progress}/${event.params.total}: ${event.params.message}`);
    }
  }
  if (done) break;
}
assert.equal(pending, "");
assert.equal(events.length, 5);
assert.deepEqual(events.slice(0, 4).map((event) => event.params.progress), [0, 1, 2, 3]);
assert.ok(events.slice(0, 4).every((event) => event.method === "notifications/progress" && event.params.progressToken === "slow-progress-test"));
assert.equal(events[4].id, 1);
assert.deepEqual(events[4].result.structuredContent, { completed: 3 });

console.log("Slow progress SSE test passed");
