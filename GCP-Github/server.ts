import express from 'express';
import { createServer as createViteServer } from 'vite';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const apiApp = require('./src/server/app.js');
const redisClient = require('./src/server/cache.js');
const runMigrations = require('./src/server/migrations.js');

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function startServer() {
  const app = express();
  const PORT = parseInt(process.env.PORT || '3000', 10);
  const isProduction = process.env.NODE_ENV === 'production';

  // Initialize DB migrations and Redis
  try {
    if (redisClient && redisClient.connect) {
      await redisClient.connect();
    }
    if (runMigrations) {
      await runMigrations();
    }
  } catch (err: any) {
    console.warn('[Server] Startup init notice:', err.message);
  }

  // Mount API endpoints (/live, /ready, /tasks, /api/stats, etc.)
  app.use(apiApp);

  if (!isProduction) {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(path.resolve(__dirname, 'dist')));
    app.get('*', (_req, res) => {
      res.sendFile(path.resolve(__dirname, 'dist', 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
  });
}

startServer();
