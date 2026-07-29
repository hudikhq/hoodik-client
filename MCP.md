# AI Access (MCP Server)

Hoodik embeds an MCP server directly in the macOS app, giving AI assistants like Claude full access to your encrypted cloud storage. Your AI can read documents, write notes, organize files, and search across everything you've stored -- while your data stays end-to-end encrypted. The Hoodik server never sees plaintext; all encryption and decryption happens locally in the app.

## What can you do with this?

**Use your AI assistant as a second brain for your private files.** Because Hoodik keeps everything encrypted and the MCP server runs locally on your machine, you get the power of AI-assisted file management without giving up privacy.

- **Ask questions about your files.** "What's in my project-proposal.md?" "Summarize the meeting notes from last week." "Find all documents mentioning the Q3 budget."
- **Create and edit documents hands-free.** "Write up a project brief based on this outline and save it to my work folder." "Update my todo list -- mark the first three items as done."
- **Organize your storage.** "Create a folder structure for my tax documents." "Move all PDFs into a 'receipts' directory." "Rename last-quarter-report.md to 2025-q4-report.md."
- **Get an overview of your storage.** "How much space am I using?" "What's the breakdown by file type?" "List everything in my projects folder."
- **Build on your own content.** "Read my existing blog post draft and suggest improvements." "Take the notes from my three meeting files and combine them into a summary."

The key difference from connecting any other cloud storage to AI: **your files are end-to-end encrypted.** The Hoodik server that stores your data cannot read it. Only your local app (and by extension, the MCP connection on your machine) can decrypt the content.

## Requirements

- **macOS** -- the MCP server is only available on macOS (hidden on iOS and Android)
- **Hoodik app** running and signed in
- An MCP-compatible AI client such as [Claude Desktop](https://claude.ai/download), [Claude Code](https://docs.anthropic.com/en/docs/claude-code), or any tool that speaks MCP

## Setup

### 1. Enable AI Access

Open the Hoodik app and go to **Account > AI Access**. Toggle **Enable AI Access** on. The app starts a local server (default port `19548`).

You'll see:
- **Port** -- configurable (default 19548, range 1024-65535)
- **Endpoint** -- `http://localhost:19548/mcp`
- **Bearer Token** -- a random token for authentication (tap **Copy** to copy it)
- **Config Snippet** -- a ready-to-paste JSON block for your AI client

### 2. Configure your AI client

Copy the config snippet from the AI Access screen and paste it into your AI client's MCP configuration. The snippet already includes your token.

**Claude Desktop** -- open **Settings > Developer > Edit Config**:

```json
{
  "mcpServers": {
    "hoodik": {
      "url": "http://localhost:19548/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN_HERE"
      }
    }
  }
}
```

**Claude Code** -- add the same block to your MCP configuration.

Replace `YOUR_TOKEN_HERE` with the token from the app, or just paste the config snippet directly.

### 3. Verify the connection

Ask your AI assistant to list your files:

> "List the files in my Hoodik storage"

It should return your decrypted file names, sizes, and types.

## Available Tools

The MCP server exposes 13 tools organized into three groups.

### File management

| Tool | What it does |
|------|-------------|
| `list_files` | Browse a directory. Returns decrypted names, sizes, types, and IDs. Omit `dir_id` for root. |
| `read_file` | Download and decrypt a file. Text files returned as UTF-8, binary as base64. Max 50 MB. |
| `write_file` | Encrypt and upload a binary or non-editable file (images, PDFs, archives). For text content, prefer `create_note`. |
| `create_directory` | Create a new encrypted directory. |
| `delete_file` | Delete a file or directory (recursive for directories). |
| `rename_file` | Rename a file or directory. |
| `move_files` | Move one or more files/directories to a different folder. |
| `search_files` | Search by file name. Privacy-preserving: names are tokenized and hashed before querying the server. |
| `storage_stats` | Storage usage, quota, and breakdown by file type. |

### Notes (editable documents)

Notes are editable text documents that can be updated in-place -- the preferred format for anything you'll want to read or change later.

| Tool | What it does |
|------|-------------|
| `list_notes` | List all editable documents across your entire storage (or scoped to a directory). |
| `read_note` | Read a note's decrypted markdown content. |
| `create_note` | Create a new editable document. Use this for markdown, plain text, documentation, configs, code -- any human-readable content. |
| `update_note` | Replace a note's content. Supports renaming in the same call. |

### When to use `write_file` vs `create_note`

- **`create_note`** for text content you might edit later (notes, docs, configs, code, markdown). Notes can be updated in-place with `update_note`.
- **`write_file`** for binary or immutable files (images, PDFs, archives, exports).

## Example Prompts

Once connected, try these:

- "List all files in my root directory"
- "Read the contents of my notes.md file"
- "Create a note called meeting-notes.md with today's meeting summary"
- "Update my todo.md -- add 'Review PR #42' to the list"
- "Search for files with 'budget' in the name"
- "How much storage am I using? What types of files do I have?"
- "Create a directory called 'projects' and move all .md files into it"
- "Read my three meeting-notes files and create a combined weekly summary"
- "Rename report-draft.pdf to report-final.pdf"

## Security

The MCP server is designed to preserve Hoodik's end-to-end encryption guarantee while giving you local AI access.

- **Localhost only.** The server binds to `127.0.0.1`. It is unreachable from the network -- only processes on your machine can connect.
- **Bearer token on every request.** Connections without a valid token are rejected with 401. The token is stored in the app's local database encrypted to your account key (hybrid X25519 + ML-KEM-768; RSA-2048 on legacy accounts).
- **Tied to your login session.** The server only runs while you are signed in. It stops automatically on logout.
- **E2E encryption preserved.** Your AI agent receives decrypted content, but the Hoodik server never does. All encryption and decryption happens locally in the app via Rust FFI -- the same code path as normal app usage.
- **No server-side changes.** The MCP server uses the same encrypted API the app already uses. Your Hoodik server requires no modifications and is completely unaware of the MCP connection.
- **Token rotation.** If you suspect the token has been compromised, open **Account > AI Access** and tap **Regenerate**. The old token is immediately invalidated.

### What the AI can and cannot access

- **Can access:** Any file you can access in the Hoodik app (your own files and files shared with you where you have the encryption key).
- **Cannot access:** Files where you don't have the encryption key, other users' files, or server-side data. The AI operates with exactly the same permissions as your logged-in session.

## Troubleshooting

### "AI Access" doesn't appear in Account settings

AI Access is only available on macOS. On iOS and Android, the option is hidden.

### Server fails to start

The most common cause is another process using the configured port. Check with:

```shell
lsof -i :19548
```

If the port is in use, change the port in **Account > AI Access** (any value between 1024 and 65535).

### AI agent can't connect

1. Make sure the Hoodik app is running and you are signed in.
2. Verify AI Access is toggled on (you should see "Running on port 19548").
3. Check that the bearer token in your AI client config matches the one in the app.
4. Test the connection manually:

```shell
curl -X POST http://localhost:19548/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"jsonrpc":"2.0","method":"ping","id":1}'
```

Expected response:

```json
{"jsonrpc":"2.0","id":1,"result":{}}
```

### File operations fail

- **"Not authenticated"** -- you may have been logged out. Sign back in and re-enable AI Access.
- **"File too large"** -- `read_file` and `write_file` have a 50 MB limit. Use the app directly for larger files.
- **"File has no encryption key"** -- the file was shared from another account whose encryption key you don't have.

## How It Works

```
AI Agent (Claude Desktop, Claude Code, etc.)
    |
    |  HTTP POST /mcp (JSON-RPC 2.0)
    |  Authorization: Bearer <token>
    |
    v
+---------------------------------------+
|  Hoodik App (macOS)                    |
|                                        |
|  MCP Server (localhost:19548)          |
|       |                                |
|  Tool Handler                          |
|       |  delegates to app services     |
|       v                                |
|  FileOperations / FileCrypto /         |
|  ApiClient / CryptoService             |
|       |                                |
|       |  encrypted requests only       |
|       v                                |
|  Hoodik Server (never sees plaintext)  |
+---------------------------------------+
```

The MCP server runs inside the app process, sharing the authenticated session and decrypted private key. It delegates every tool call to the same services the app UI uses -- `FileOperations` for uploads/downloads, `FileCrypto` for encryption/decryption, `ApiClient` for server communication. The protocol is MCP's Streamable HTTP transport (JSON-RPC 2.0 over HTTP POST).

Sessions are tracked per-client and cleaned up after 30 minutes of inactivity.
