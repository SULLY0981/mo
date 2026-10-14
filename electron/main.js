// Desktop wrapper for Steam. Runs the HTML5 game in a native window and
// bridges achievements to Steam via steamworks.js when Steam is available.
const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');

let steam = null;
try {
  const steamworks = require('steamworks.js');
  // Steam sets the app id; steam_appid.txt next to the exe is used during development.
  let appId = Number(process.env.SteamAppId || process.env.STEAM_APP_ID || 0);
  const idFile = path.join(path.dirname(app.getPath('exe')), 'steam_appid.txt');
  if (!appId && fs.existsSync(idFile)) appId = Number(fs.readFileSync(idFile, 'utf8').trim());
  if (appId) {
    steam = steamworks.init(appId);
    steamworks.electronEnableSteamOverlay();
  }
} catch (e) {
  console.log('Steam not available, running standalone:', e.message);
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 720,
    minWidth: 960,
    minHeight: 540,
    fullscreen: true,
    backgroundColor: '#07050d',
    title: 'The Last Lantern',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      backgroundThrottling: false,
    },
  });
  win.setMenu(null);
  win.loadFile(path.join(__dirname, '..', 'game', 'index.html'));
}

ipcMain.on('steam-achievement', (_e, id) => {
  try { if (steam) steam.achievement.activate(String(id)); } catch (err) { console.log('achievement failed', err.message); }
});
ipcMain.on('toggle-fullscreen', (e) => {
  const w = BrowserWindow.fromWebContents(e.sender);
  if (w) w.setFullScreen(!w.isFullScreen());
});
ipcMain.on('quit', () => app.quit());

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());
