const express = require('express');
const pool = require('./db');
const redisClient = require('./cache');

const app = express();

app.use(express.json());

// ========================================
// Liveness probe
// ========================================
app.get('/live', (req, res) => {
  res.status(200).json({
    status: 'alive'
  });
});

// ========================================
// Readiness probe
// ========================================
app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    await redisClient.ping();
    res.status(200).json({
      status: 'ready'
    });
  } catch (error) {
    console.error('Readiness check failed:', error);
    res.status(503).json({
      status: 'not ready'
    });
  }
});

// ========================================
// Diagnostics & stats
// ========================================
app.get('/api/stats', async (req, res) => {
  try {
    const stats = redisClient.getStats ? redisClient.getStats() : {};
    const taskCountResult = await pool.query('SELECT id, completed FROM tasks');
    const tasks = taskCountResult.rows || [];
    const total = tasks.length;
    const completed = tasks.filter(t => t.completed).length;

    res.json({
      database: {
        mode: pool.isFallback ? (pool.isFallback() ? 'In-Memory Fallback' : 'PostgreSQL Live') : 'Connected',
        totalTasks: total,
        completedTasks: completed,
        pendingTasks: total - completed
      },
      cache: {
        mode: stats.isFallback ? 'In-Memory Cache' : 'Redis Cluster/Instance',
        hits: stats.hits || 0,
        misses: stats.misses || 0,
        keys: stats.cachedKeys || []
      },
      environment: {
        port: process.env.PORT || 3000,
        nodeEnv: process.env.NODE_ENV || 'development'
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ========================================
// Get all tasks
// ========================================
app.get('/tasks', async (req, res) => {
  try {
    let cached = null;
    try {
      cached = await redisClient.get('tasks:all');
    } catch (cacheErr) {
      console.warn('Cache read bypass:', cacheErr.message);
    }

    if (cached) {
      return res.status(200).json(typeof cached === 'string' ? JSON.parse(cached) : cached);
    }

    const result = await pool.query(`
      SELECT id, title, completed, created_at
      FROM tasks
      ORDER BY created_at DESC
    `);

    try {
      await redisClient.setEx(
        'tasks:all',
        60,
        JSON.stringify(result.rows)
      );
    } catch (cacheErr) {
      console.warn('Cache write bypass:', cacheErr.message);
    }

    res.status(200).json(result.rows);
  } catch (error) {
    console.error('GET /tasks failed:', error);
    res.status(500).json({
      error: 'Internal server error'
    });
  }
});

// ========================================
// Create task
// ========================================
app.post('/tasks', async (req, res) => {
  try {
    const { title } = req.body || {};

    if (
      !title ||
      typeof title !== 'string' ||
      !title.trim()
    ) {
      return res.status(400).json({
        error: 'Title is required'
      });
    }

    const result = await pool.query(
      `
      INSERT INTO tasks (title)
      VALUES ($1)
      RETURNING id, title, completed, created_at
      `,
      [title.trim()]
    );

    // Invalidate cache safely
    try {
      await redisClient.del('tasks:all');
    } catch (cacheErr) {
      console.warn('Cache invalidate bypass:', cacheErr.message);
    }

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('POST /tasks failed:', error);
    res.status(500).json({
      error: 'Internal server error'
    });
  }
});

// ========================================
// Toggle task completion
// ========================================
app.patch('/tasks/:id', async (req, res) => {
  try {
    const taskId = parseInt(req.params.id, 10);
    if (isNaN(taskId)) {
      return res.status(400).json({ error: 'Invalid task ID' });
    }

    const result = await pool.query(
      `UPDATE tasks SET completed = NOT completed WHERE id = $1 RETURNING id, title, completed, created_at`,
      [taskId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    try {
      await redisClient.del('tasks:all');
    } catch {
      // ignore
    }

    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error('PATCH /tasks failed:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ========================================
// Delete task
// ========================================
app.delete('/tasks/:id', async (req, res) => {
  try {
    const taskId = parseInt(req.params.id, 10);
    if (isNaN(taskId)) {
      return res.status(400).json({ error: 'Invalid task ID' });
    }

    const result = await pool.query(
      `DELETE FROM tasks WHERE id = $1 RETURNING id`,
      [taskId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    try {
      await redisClient.del('tasks:all');
    } catch {
      // ignore
    }

    res.status(200).json({ message: 'Task deleted successfully', id: taskId });
  } catch (error) {
    console.error('DELETE /tasks failed:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = app;
