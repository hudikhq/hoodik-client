// MCP tool definitions for Hoodik file operations.
//
// Each tool is a JSON Schema object that describes the tool's name,
// description, and input parameters. These are returned by the
// `tools/list` MCP method.

const List<Map<String, dynamic>> mcpTools = [
  {
    'name': 'list_files',
    'description':
        'List files, notes, and directories in a folder. '
        'Includes markdown notes. Returns decrypted names, sizes, types, and IDs. '
        'Omit dir_id to list the root. Walk from a known folder id rather than guessing paths. '
        'Prefer resolve_path when you have a plaintext path.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'dir_id': {
          'type': 'string',
          'description': 'Directory ID to list (omit for root)',
        },
      },
    },
  },
  {
    'name': 'resolve_path',
    'description':
        'Walk a decrypted folder tree by plaintext path and return each '
        'segment in order with its id and metadata. Use this instead of '
        'guessing UUIDs: start from a known folder (dir_id) or omit dir_id '
        'for the vault root, then pass returned ids to list_files, read_note, '
        'update_note, and other tools. Leading slash is optional; backslashes '
        'are treated as slashes. resolved is true only when every segment exists.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description':
              'Path to resolve, e.g. "/Work/thelab/CLAUDE.md" or "Work/thelab/CLAUDE.md"',
        },
        'dir_id': {
          'type': 'string',
          'description':
              'Folder UUID to start from (omit or empty for vault root)',
        },
      },
      'required': ['path'],
    },
  },
  {
    'name': 'read_file',
    'description':
        'Download and decrypt a file. Returns the plaintext content. '
        'Text files are returned as UTF-8 strings. '
        'Binary files are returned as base64-encoded strings. '
        'Maximum file size: 50 MB.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'file_id': {'type': 'string', 'description': 'ID of the file to read'},
      },
      'required': ['file_id'],
    },
  },
  {
    'name': 'write_file',
    'description':
        'Upload a binary or non-editable file (images, PDFs, archives, etc.). '
        'The file is encrypted client-side before upload. '
        'A new upload returns {success, id, name, size, existed: false}. '
        'If a file with this name already exists in the parent, returns that '
        'id with existed: true without overwriting — there is no update_file '
        'for binaries; use create_note/update_note for text. '
        'For text documents, markdown, or any content you may want to read or '
        'update later, use create_note instead — it creates an editable file.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': 'File name (e.g. "notes.md", "data.json")',
        },
        'content': {
          'type': 'string',
          'description': 'File content (text or base64-encoded binary)',
        },
        'dir_id': {
          'type': 'string',
          'description': 'Parent directory ID (omit for root)',
        },
        'encoding': {
          'type': 'string',
          'enum': ['text', 'base64'],
          'description': 'Content encoding (default: "text")',
        },
      },
      'required': ['name', 'content'],
    },
  },
  {
    'name': 'create_directory',
    'description':
        'Create a new encrypted directory. Returns {id, name}. '
        'Name-idempotent: if a directory with this name already exists in the '
        'parent, returns that existing id instead of failing. '
        'Use the returned id for later list_files, create_note, and write_file calls.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': 'Directory name'},
        'dir_id': {
          'type': 'string',
          'description': 'Parent directory ID (omit for root)',
        },
      },
      'required': ['name'],
    },
  },
  {
    'name': 'delete_file',
    'description': 'Delete a file or directory (recursive for directories).',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'file_id': {
          'type': 'string',
          'description': 'ID of the file or directory to delete',
        },
      },
      'required': ['file_id'],
    },
  },
  {
    'name': 'rename_file',
    'description': 'Rename a file or directory.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'file_id': {
          'type': 'string',
          'description': 'ID of the file or directory to rename',
        },
        'new_name': {
          'type': 'string',
          'description': 'New name for the file or directory',
        },
      },
      'required': ['file_id', 'new_name'],
    },
  },
  {
    'name': 'move_files',
    'description': 'Move files or directories to a different parent directory.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'file_ids': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'IDs of files/directories to move',
        },
        'target_dir_id': {
          'type': 'string',
          'description': 'Target directory ID (omit to move to root)',
        },
      },
      'required': ['file_ids'],
    },
  },
  {
    'name': 'search_files',
    'description':
        'Search files and notes by name and note content. Matching is '
        'whole-word and case-insensitive; the server only ever sees hashed '
        'tags, so there is no fuzzy or substring matching — retry with word '
        'variants (singular/plural, stem) when a query comes up empty. An '
        'exact full filename ranks first; multi-word queries match any word, '
        'best-ranked first. Use find_in_note to locate the query inside a '
        'matched note (or read_note for the full body). '
        'Optional dir_id scopes the search to one folder.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Search query'},
        'dir_id': {
          'type': 'string',
          'description': 'Scope search to a directory (omit for all files)',
        },
        'limit': {
          'type': 'integer',
          'description': 'Maximum number of results (default: 20)',
        },
      },
      'required': ['query'],
    },
  },
  {
    'name': 'storage_stats',
    'description':
        'Get storage usage statistics including used space, quota, '
        'and breakdown by file type.',
    'inputSchema': {'type': 'object', 'properties': {}},
  },
  {
    'name': 'list_notes',
    'description':
        'List editable notes (markdown). Omit dir_id for every note in the account. '
        'Pass dir_id to list notes in that folder only. '
        'Each result includes id, name, and dir_id (the parent folder).',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'dir_id': {
          'type': 'string',
          'description': 'Scope to a specific directory (omit for all notes)',
        },
      },
    },
  },
  {
    'name': 'read_note',
    'description':
        'Read the content of an editable markdown note. '
        'Returns the decrypted markdown text.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'file_id': {'type': 'string', 'description': 'ID of the note to read'},
      },
      'required': ['file_id'],
    },
  },
  {
    'name': 'find_in_note',
    'description':
        'Find a query inside a note and return match excerpts with positions. '
        'search_files finds which note matched; find_in_note finds where '
        'inside it. Does not return the full note body — use read_note for that. '
        'Requires file_id and query. Optional max_matches (default 20, cap 50), '
        'context (excerpt padding chars, default 80, cap 200), and '
        'case_sensitive (default false).',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'file_id': {
          'type': 'string',
          'description': 'ID of the note to search',
        },
        'query': {
          'type': 'string',
          'description': 'Text to find inside the note',
        },
        'max_matches': {
          'type': 'integer',
          'description': 'Maximum matches to return (default: 20, max: 50)',
        },
        'context': {
          'type': 'integer',
          'description':
              'Characters of excerpt padding around each match '
              '(default: 80, max: 200)',
        },
        'case_sensitive': {
          'type': 'boolean',
          'description': 'Match case-sensitively (default: false)',
        },
      },
      'required': ['file_id', 'query'],
    },
  },
  {
    'name': 'create_note',
    'description':
        'Create an editable markdown note in a folder. Preferred for docs, configs, '
        'and agent context. If a note with this name already exists in the parent, '
        'updates its content (upsert) and returns that note id. '
        'Returns {success, id, file_id, name, existed}: existed true means the '
        'note was updated rather than newly created.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': 'Note name (e.g. "meeting-notes.md")',
        },
        'content': {'type': 'string', 'description': 'Markdown content'},
        'dir_id': {
          'type': 'string',
          'description': 'Parent directory ID (omit for root)',
        },
      },
      'required': ['name', 'content'],
    },
  },
  {
    'name': 'update_note',
    'description':
        'Update the content of an existing editable note. '
        'Replaces the entire content with the new text.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'file_id': {
          'type': 'string',
          'description': 'ID of the note to update',
        },
        'content': {
          'type': 'string',
          'description': 'New markdown content (replaces existing)',
        },
        'name': {
          'type': 'string',
          'description':
              'New name for the note (optional, keeps current if omitted)',
        },
      },
      'required': ['file_id', 'content'],
    },
  },
  {
    'name': 'health',
    'description':
        'Report whether the MCP server is running, whether the app is '
        'PIN-locked, and whether the agent can mutate. No arguments. '
        'Allowed while locked. Does not return tokens, account email, or paths. '
        'Returns {running, locked, ready}: ready is true only when the server '
        'is running and the user is unlocked.',
    'inputSchema': {'type': 'object', 'properties': {}},
  },
];
