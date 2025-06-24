# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Application Overview

This is a Focus Task Manager built with Electron - a desktop task management application designed for productivity and focus. The app features a clean, dark-themed interface with priority-based task organization, subtask support, integrated timer functionality, and note-taking capabilities.

## Architecture

- **Main Process**: `src/main.js` - Electron main process handling window management, IPC communication, and app lifecycle
- **Renderer Process**: `dist/index.html` - Main UI with embedded CSS and JavaScript for task management, timer, and notes
- **Preload Script**: `src/preload.js` - Secure bridge between main and renderer processes, exposes window controls and settings APIs
- **Task Storage**: Browser localStorage for task persistence and settings
- **UI Pages**: 
  - `dist/index.html` - Main task management interface
  - `dist/edit-tasks.html` - Task editing interface
  - `dist/settings.html` - Application settings

## Key Features

- **5-Priority Task System**: Fixed 5 tasks ordered by priority (Critical, High, Medium, Low, Minimal)
- **Hierarchical Tasks**: Main tasks with expandable subtasks
- **Focus Timer**: Pomodoro-style timer with start/pause/reset/save functionality
- **Notes Integration**: Auto-saving textarea for capturing thoughts and timer logs
- **Window Management**: Custom frameless window with minimize/close controls
- **Dual Environment**: Works in both Electron desktop app and browser

## Common Development Commands

```bash
# Development
npm run dev          # Start in development mode with hot reload
npm start           # Start application normally

# Building
npm run build       # Build with electron-builder
npm run build:win   # Build for Windows
npm run build:mac   # Build for macOS  
npm run build:linux # Build for Linux
npm run pack        # Package without building installer
npm run dist        # Create distribution files
```

## Data Schema

Tasks follow this structure (see `tasks-schema.json`):
- **id**: Unique identifier
- **title**: Task description
- **priority**: 1-5 (1=Critical, 5=Minimal)
- **completed**: Boolean completion status
- **collapsed**: Boolean subtask visibility
- **subtasks**: Array of subtask objects with id, title, completed

## Security & IPC

The app uses secure IPC communication:
- Context isolation enabled
- Node integration disabled
- Protected APIs exposed via `contextBridge` in preload script
- Window controls, settings management, and platform detection available through `window.electronAPI`

## File Structure

- `/src/` - Electron source files (main.js, preload.js)
- `/dist/` - Built HTML/CSS/JS files for renderer
- `/assets/` - Application icons and resources
- `/node_modules/` - Dependencies
- `package.json` - App configuration and build settings
- `tasks-schema.json` - Example task data structure

## Development Notes

- Tasks are limited to exactly 5 items, auto-filled with empty tasks if needed
- UI supports both Electron and browser environments with feature detection
- Timer integrates with notes system for time tracking
- Accordion-style subtask expansion (only one expanded at a time)
- Keyboard shortcuts: Ctrl/Cmd+Space (timer), Ctrl/Cmd+R (reset), Ctrl/Cmd+S (save), Ctrl/Cmd+E (edit)