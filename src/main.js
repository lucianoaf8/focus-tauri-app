const { app, BrowserWindow, ipcMain, Menu } = require('electron');
const path = require('path');

let mainWindow;
let settingsWindow;

// Enable live reload for development
if (process.argv.includes('--dev')) {
  require('electron-reload')(__dirname, {
    electron: path.join(__dirname, '..', 'node_modules', '.bin', 'electron'),
    hardResetMethod: 'exit'
  });
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 400,
    height: 800,        // Increased from 700
    minWidth: 350,
    minHeight: 700,     // Increased from 600
    maxWidth: 450,
    center: true,
    resizable: true,
    frame: false,       // Remove the native frame completely
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    icon: path.join(__dirname, '..', 'assets', 'icon.png'),
    show: false
  });

  mainWindow.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
    if (settingsWindow) {
      settingsWindow.close();
    }
  });

  // Handle settings window creation
  ipcMain.handle('open-settings', () => {
    if (settingsWindow) {
      settingsWindow.focus();
      return;
    }

    settingsWindow = new BrowserWindow({
      width: 600,
      height: 700,
      minWidth: 500,
      minHeight: 600,
      center: true,
      resizable: true,
      parent: mainWindow,
      modal: false,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        preload: path.join(__dirname, 'preload.js')
      },
      icon: path.join(__dirname, '..', 'assets', 'icon.png'),
      title: 'Settings'
    });

    settingsWindow.loadFile(path.join(__dirname, '..', 'dist', 'settings.html'));

    settingsWindow.on('closed', () => {
      settingsWindow = null;
    });
  });

  // Handle settings save
  ipcMain.handle('save-settings', (event, settings) => {
    // Apply settings to main window
    if (settings.alwaysOnTop !== undefined) {
      mainWindow.setAlwaysOnTop(settings.alwaysOnTop);
    }
    
    if (settings.opacity !== undefined) {
      mainWindow.setOpacity(settings.opacity);
    }
    
    // You can store settings in a config file or user data
    console.log('Settings saved:', settings);
  });

  // Handle close settings window
  ipcMain.handle('close-settings', () => {
    if (settingsWindow) {
      settingsWindow.close();
    }
  });

  // Window control handlers
  ipcMain.handle('minimize-window', () => {
    const focusedWindow = BrowserWindow.getFocusedWindow();
    if (focusedWindow) {
      focusedWindow.minimize();
    }
  });

  ipcMain.handle('maximize-window', () => {
    const focusedWindow = BrowserWindow.getFocusedWindow();
    if (focusedWindow) {
      if (focusedWindow.isMaximized()) {
        focusedWindow.unmaximize();
      } else {
        focusedWindow.maximize();
      }
    }
  });

  ipcMain.handle('close-window', () => {
    const focusedWindow = BrowserWindow.getFocusedWindow();
    if (focusedWindow) {
      focusedWindow.close();
    }
  });
}

app.whenReady().then(() => {
  // Remove the menu bar completely
  Menu.setApplicationMenu(null);
  
  createMainWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Security: Prevent new window creation
app.on('web-contents-created', (event, contents) => {
  contents.on('new-window', (event, navigationUrl) => {
    event.preventDefault();
  });
});

// Handle app protocol for deep linking (optional)
app.setAsDefaultProtocolClient('focus-task-manager');