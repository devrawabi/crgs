import { defineConfig, type Plugin, type Connect } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'
import fs from 'fs'

const apkPath = path.resolve(__dirname, '../backend/uploads/mobile-app.apk')
const publicApkPath = path.resolve(__dirname, 'public/app')

function resolveApkPath(): string | null {
  if (fs.existsSync(apkPath)) return apkPath
  if (fs.existsSync(publicApkPath)) return publicApkPath
  return null
}

function serveMobileApk(): Plugin {
  const handler: Connect.NextHandleFunction = (req, res, next) => {
    const url = req.url?.split('?')[0]
    if (url !== '/app' && url !== '/app/') {
      next()
      return
    }

    const file = resolveApkPath()
    if (!file) {
      res.statusCode = 404
      res.setHeader('Content-Type', 'text/plain; charset=utf-8')
      res.end('Mobile app APK not found')
      return
    }

    const stat = fs.statSync(file)
    res.statusCode = 200
    res.setHeader('Content-Type', 'application/vnd.android.package-archive')
    res.setHeader(
      'Content-Disposition',
      'attachment; filename="CRGS-mobile-app.apk"'
    )
    res.setHeader('Content-Length', String(stat.size))
    res.setHeader('Cache-Control', 'public, max-age=300')
    fs.createReadStream(file).pipe(res)
  }

  return {
    name: 'serve-mobile-apk',
    configureServer(server) {
      server.middlewares.use(handler)
    },
    configurePreviewServer(server) {
      server.middlewares.use(handler)
    },
  }
}

const sharedServer = {
  host: '0.0.0.0',
  port: 5317,
  strictPort: true,
  allowedHosts: ['crgs.rfoodinternational.com'],
  proxy: {
    // Same machine as Vite — avoid LAN IP (breaks when IP changes / backend down).
    '/api': {
      target: 'http://127.0.0.1:5318',
      changeOrigin: true,
    },
  },
}

export default defineConfig({
  plugins: [react(), tailwindcss(), serveMobileApk()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: sharedServer,
  preview: sharedServer,
})
