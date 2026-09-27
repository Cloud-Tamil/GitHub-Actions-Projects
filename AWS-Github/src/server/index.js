require('dotenv').config();
const app = require('./app');
const pool = require('./db');
const redisClient = require('./cache');
const runMigrations = require('./migrations');

const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';
let server;

async function start() {
  try {
    console.log('Connecting to Redis...');
    await redisClient.connect();
    console.log('Redis connected');

    console.log('Running database migrations...');
    await runMigrations();
    console.log('Database ready');

    server = app.listen(PORT, HOST, () => {
      console.log(`Server running on http://${HOST}:${PORT}`);
    });
  } catch (error) {
    console.error('Application startup failed:', error);
    process.exit(1);
  }
}

// ========================================
// Graceful shutdown
// ========================================
async function shutdown(signal) {
  console.log(`${signal} received. Shutting down...`);
  if (server) {
    server.close(async () => {
      try {
        await redisClient.quit();
        await pool.end();
        console.log('Connections closed');
        process.exit(0);
      } catch (error) {
        console.error('Shutdown error:', error);
        process.exit(1);
      }
    });
  } else {
    process.exit(0);
  }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

if (require.main === module) {
  start();
}

module.exports = { start, shutdown };
