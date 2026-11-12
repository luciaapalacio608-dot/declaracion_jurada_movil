// Serves the release build (build/web) on 127.0.0.1:8001 for the phone
// connected by USB cable (adb reverse tcp:8001 tcp:8001). Only this computer
// can reach it. No dependencies: `node tool/servir.js`.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', 'build', 'web');
const PORT = 8001;
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.css': 'text/css',
  '.symbols': 'text/plain',
};

http
  .createServer((request, response) => {
    const urlPath = decodeURIComponent(new URL(request.url, 'http://x').pathname);
    let file = path.normalize(path.join(ROOT, urlPath));
    if (!file.startsWith(ROOT)) {
      response.writeHead(403).end();
      return;
    }
    // Routes of the app (/login, /declarations...) all load index.html.
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      file = path.join(ROOT, 'index.html');
    }
    response.writeHead(200, {
      'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    fs.createReadStream(file).pipe(response);
  })
  .listen(PORT, '127.0.0.1', () => {
    console.log(`Sirviendo build/web en http://127.0.0.1:${PORT}`);
  });
