const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  // Window management
  openSettings: () => ipcRenderer.invoke('open-settings'),
  closeSettings: () => ipcRenderer.invoke('close-settings'),
  
  // Settings management
  saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
  
  // Window controls
  minimizeWindow: () => ipcRenderer.invoke('minimize-window'),
  maximizeWindow: () => ipcRenderer.invoke('maximize-window'),
  closeWindow: () => ipcRenderer.invoke('close-window'),
  
  // Get platform info
  platform: process.platform,
  
  // Optional: Add other APIs as needed
});

// Create a simplified window object that mimics Tauri's structure
contextBridge.exposeInMainWorld('__ELECTRON__', {
  window: {
    WebviewWindow: class {
      constructor(label, options) {
        this.label = label;
        this.options = options;
        
        if (label === 'settings') {
          return {
            setFocus: () => ipcRenderer.invoke('open-settings'),
            once: (event, callback) => {
              if (event === 'tauri://created') {
                // Simulate successful creation
                setTimeout(callback, 100);
              }
            }
          };
        }
      }
      
      static getByLabel(label) {
        if (label === 'settings') {
          // Return null if no settings window exists
          return null;
        }
        return null;
      }
    }
  }
});

// Optional: Expose version info
contextBridge.exposeInMainWorld('APP_VERSION', '1.0.0');