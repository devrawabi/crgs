module.exports = {
  apps: [
    {
      name: 'crgs-api',
      script: 'run.py',
      cwd: 'D:\\DiLSHAN\\CRGS-Admin\\CRGS-Admin\\backend',
      // pythonw = no console window on Windows
      interpreter:
        'D:\\DiLSHAN\\CRGS-Admin\\CRGS-Admin\\backend\\venv\\Scripts\\pythonw.exe',
      windowsHide: true,
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_restarts: 20,
      env: {
        PORT: '5318',
        FLASK_ENV: 'production',
        FLASK_DEBUG: '0',
        CORS_ALLOW_ALL: 'false',
        PYTHONUNBUFFERED: '1',
      },
    },
    {
      name: 'crgs-web',
      script:
        'D:\\DiLSHAN\\CRGS-Admin\\CRGS-Admin\\frontend\\node_modules\\vite\\bin\\vite.js',
      args: 'preview --host 0.0.0.0 --port 5317 --strictPort',
      cwd: 'D:\\DiLSHAN\\CRGS-Admin\\CRGS-Admin\\frontend',
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
      script: 'C:\\cloudflared\\cloudflared.exe',
      args:
        'tunnel --config D:\\DiLSHAN\\CRGS-Admin\\CRGS-Admin\\cloudflare\\config.yml run 382e5d55-e412-44e9-8e41-cee8f4ca79b4',
      cwd: 'D:\\DiLSHAN\\CRGS-Admin\\CRGS-Admin\\cloudflare',
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
