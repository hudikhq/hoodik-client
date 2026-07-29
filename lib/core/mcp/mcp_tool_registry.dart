// MCP tool definitions for Hoodik file operations.
//
// Each tool is a JSON Schema object that describes the tool's name,
// description, and input parameters. These are returned by the
// `tools/list` MCP method.

const List<Map<String, dynamic>> mcpTools = [
  {
    'name': 'list_files',
    'description':
        'List files and directories in a folder. '
        'Returns decrypted file names, sizes, types, and IDs. '
        'Omit dir_id to list the root directory.',
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
    'description': 'Create a new encrypted directory.',
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
        'Search files by name. Uses privacy-preserving search '
        '(names are tokenized and hashed before sending to the server).',
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
        'List all editable documents (notes) across the entire storage. '
        'Unlike list_files which shows one directory, this returns all notes '
        'regardless of which folder they are in.',
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
    'name': 'create_note',
    'description':
        'Create a new editable document. Preferred for all text content '
        '(markdown, plain text, documentation, notes, configs, code, etc.). '
        'Unlike write_file, notes can be updated in-place with update_note. '
        'Use this instead of write_file for any human-readable content.',
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
];
