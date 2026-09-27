const request = require('supertest');
const app = require('../src/server/app');
const pool = require('../src/server/db');
const redisClient = require('../src/server/cache');

describe('Task Manager API', () => {
  beforeAll(async () => {
    if (!redisClient.isOpen && redisClient.connect) {
      try {
        await redisClient.connect();
      } catch (err) {
        console.warn('Test: Redis connect notice:', err.message);
      }
    }
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS tasks (
          id SERIAL PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          completed BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT NOW()
        )
      `);
    } catch (err) {
      console.warn('Test: DB query notice:', err.message);
    }
  });

  afterAll(async () => {
    try {
      if (redisClient.isOpen && redisClient.quit) {
        await redisClient.quit();
      }
      if (pool.end) {
        await pool.end();
      }
    } catch (err) {
      console.warn('Test: Teardown notice:', err.message);
    }
  });

  test('GET /live returns 200', async () => {
    const response = await request(app).get('/live');
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('alive');
  });

  test('GET /ready returns 200', async () => {
    const response = await request(app).get('/ready');
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('ready');
  });

  test('POST /tasks validates title', async () => {
    const response = await request(app).post('/tasks').send({});
    expect(response.statusCode).toBe(400);
  });

  test('POST /tasks creates a task', async () => {
    const response = await request(app)
      .post('/tasks')
      .send({
        title: 'Write production tests'
      });
    expect(response.statusCode).toBe(201);
    expect(response.body.title).toBe('Write production tests');
  });

  test('GET /tasks returns tasks', async () => {
    const response = await request(app).get('/tasks');
    expect(response.statusCode).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
  });
});
