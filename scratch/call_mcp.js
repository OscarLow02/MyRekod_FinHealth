const { spawn } = require('child_process');

const args = process.argv.slice(2);
if (args.length < 2) {
  console.error("Usage: node call_mcp.js <command_json> <tool_name> [tool_args_json]");
  process.exit(1);
}

const cmdConfig = JSON.parse(args[0]); // e.g. {"command":"npx","args":["-y","mcp-remote","..."]}
const toolName = args[1];
const toolArgs = args[2] ? JSON.parse(args[2]) : {};

console.log("Spawning server:", cmdConfig.command, cmdConfig.args.join(' '));
const child = spawn(cmdConfig.command, cmdConfig.args, {
  env: { ...process.env, ...cmdConfig.env }
});

let buffer = '';
let step = 0;
let requestCount = 1;

child.stdout.on('data', (data) => {
  buffer += data.toString();
  let lineEnd;
  while ((lineEnd = buffer.indexOf('\n')) !== -1) {
    const line = buffer.substring(0, lineEnd).trim();
    buffer = buffer.substring(lineEnd + 1);
    if (!line) continue;
    
    console.log("Server response:", line);
    try {
      const response = JSON.parse(line);
      if (response.id === 1) {
        // Initialize response received. Send initialized notification.
        console.log("Sending notifications/initialized...");
        child.stdin.write(JSON.stringify({
          jsonrpc: "2.0",
          method: "notifications/initialized"
        }) + '\n');
        
        // Now call the tool.
        console.log(`Calling tool: ${toolName}...`);
        child.stdin.write(JSON.stringify({
          jsonrpc: "2.0",
          method: "tools/call",
          params: {
            name: toolName,
            arguments: toolArgs
          },
          id: 2
        }) + '\n');
      } else if (response.id === 2) {
        // Tool call response received.
        console.log("Tool call completed successfully.");
        console.log("RESULT_JSON:" + JSON.stringify(response.result));
        child.kill();
        process.exit(0);
      }
    } catch (e) {
      console.error("Parse error on line:", line, e);
    }
  }
});

child.stderr.on('data', (data) => {
  console.error("Server stderr:", data.toString().trim());
});

child.on('close', (code) => {
  console.log("Server process closed with code:", code);
});

// Start the protocol by sending initialize request
console.log("Sending initialize...");
child.stdin.write(JSON.stringify({
  jsonrpc: "2.0",
  method: "initialize",
  params: {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: {
      name: "test-client",
      version: "1.0.0"
    }
  },
  id: 1
}) + '\n');
