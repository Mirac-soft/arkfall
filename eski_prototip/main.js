// Electron masaüstü penceresi (Steam sürümü bunun üzerine kurulacak)
const { app, BrowserWindow } = require('electron');

app.whenReady().then(() => {
  const win = new BrowserWindow({ width: 1280, height: 720, backgroundColor: '#000000', autoHideMenuBar: true, title: 'Gökkalkan' });
  win.loadFile('index.html');
});
app.on('window-all-closed', () => app.quit());
