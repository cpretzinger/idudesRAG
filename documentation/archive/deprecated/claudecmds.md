Usage: claude mcp [options] [command]

Configure and manage MCP servers

Options:
-h, --help Display help for command

Commands:
serve [options] Start the Claude Code MCP server
add [options] <name> <commandOrUrl> [args...] Add a server
remove [options] <name> Remove an MCP server
list List configured MCP servers
get <name> Get details about an MCP server
add-json [options] <name> <json> Add an MCP server (stdio or SSE) with a JSON string
add-from-claude-desktop [options] Import MCP servers from Claude Desktop (Mac and WSL only)
reset-project-choices Reset all approved and rejected project-scoped (.mcp.json) servers within this project
help [command] display help for command
