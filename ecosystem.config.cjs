const path = require('path');

const root = __dirname;
const backend = path.join(root, 'backend');
const frontend = path.join(root, 'frontend');
const cloudflare = path.join(root, 'cloudflare');
const pythonw = path.join(backend, 'venv', 'Scripts', 'pythonw.exe');
const viteBin = path.join(frontend, 'node_modules', 'vite', 'bin', 'vite.js');
const cloudflared =
  process.env.CLOUDFLARED_PATH || 'C:\\cloudflared\\cloudflared.exe';
const tunnelId =
  process.env.CLOUDFLARE_TUNNEL_ID || '382e5d55-e412-44e9-8e41-cee8f4ca79b4';

module.exports = {
  apps: [
    {
      name: 'crgs-api',
      script: 'run.py',
      cwd: backend,
      // pythonw = no console window on Windows
      interpreter: pythonw,
      windowsHide: true,
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_restarts: 20,
      // Single instance: one Oracle pool per process. Scale via Waitress
      // threads + ORACLE_POOL_MAX (keep pool max >= threads).
      env: {
        PORT: '5318',
        FLASK_ENV: 'production',
        FLASK_DEBUG: '0',
        CORS_ALLOW_ALL: 'false',
        PYTHONUNBUFFERED: '1',
        WAITRESS_THREADS: '12',
        ORACLE_POOL_MIN: '4',
        ORACLE_POOL_MAX: '16',
        ORACLE_POOL_INCREMENT: '2',
        ORACLE_ITEMMASTER_UPDATED_COLUMN: 'LAST_UPDATED',
        // Full admin: all tabs. Manager: all except Dashboard + Users.
        // Call center: Call Center tab only. Only role 1 may create roles 1 & 9.
        ADMIN_ROLE_CODES: '1,3,4,6,8',
        MANAGER_ROLE_CODES: '2,5',
        CALL_CENTER_ROLE_CODES: '9',
      },
    },
    {
      name: 'crgs-web',
      script: viteBin,
      args: 'preview --host 0.0.0.0 --port 5317 --strictPort',
      cwd: frontend,
      interpreter: 'node',
      windowsHide: true,
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_restarts: 20,
    },
    {
      name: 'crgs-tunnel',
      script: cloudflared,
      args: `tunnel --config ${path.join(cloudflare, 'config.yml')} run ${tunnelId}`,
      cwd: cloudflare,
      interpreter: 'none',
      windowsHide: true,
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_restarts: 20,
    },
  ],
};
