const fs = require('fs');
const { spawn } = require('child_process');

const schemaPath = process.argv[2] || 'scratch/wireframe_schema.json';
if (!fs.existsSync(schemaPath)) {
  console.error(`Error: Schema file not found at ${schemaPath}`);
  process.exit(1);
}

const schemaContent = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));

const cmdConfig = {
  command: "npx",
  args: ["-y", "mcp-remote", "https://mcp.wirekitty.dev/mcp"]
};

console.log("Spawning server:", cmdConfig.command, cmdConfig.args.join(' '));
const child = spawn(cmdConfig.command, cmdConfig.args);

let buffer = '';

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
        console.log(`Calling tool: create_wireframe...`);
        child.stdin.write(JSON.stringify({
          jsonrpc: "2.0",
          method: "tools/call",
          params: {
            name: "create_wireframe",
            arguments: {
              schema: schemaContent,
              updateWireframeId: "170166f0-2eb5-4c29-8258-af922511f51d"
            }
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
