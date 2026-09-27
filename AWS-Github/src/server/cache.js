const { createClient } = require('redis');
require('dotenv').config();

class InMemoryCache {
  constructor() {
    this.store = new Map();
    this.isOpen = true;
    this.hits = 0;
    this.misses = 0;
  }

  async connect() {
    this.isOpen = true;
    return Promise.resolve();
  }

  async ping() {
    return 'PONG';
  }

  async get(key) {
    const entry = this.store.get(key);
    if (!entry) {
      this.misses++;
      return null;
    }
    if (entry.expiresAt && Date.now() > entry.expiresAt) {
      this.store.delete(key);
      this.misses++;
      return null;
    }
    this.hits++;
    return entry.value;
  }

  async setEx(key, seconds, value) {
    const expiresAt = Date.now() + (seconds * 1000);
    this.store.set(key, { value, expiresAt });
    return 'OK';
  }

  async set(key, value) {
    this.store.set(key, { value, expiresAt: null });
    return 'OK';
  }

  async del(key) {
    const existed = this.store.delete(key);
    return existed ? 1 : 0;
  }

  async quit() {
    this.isOpen = false;
    return Promise.resolve();
  }

  on(event, handler) {
    // no-op
    return this;
  }
}

const fallbackCache = new InMemoryCache();
let activeClient = fallbackCache;

const hasConfiguredRedis = Boolean(process.env.REDIS_URL && !process.env.REDIS_URL.includes('localhost'));

if (hasConfiguredRedis) {
  try {
    const realClient = createClient({
      url: process.env.REDIS_URL
    });

    realClient.on('error', (err) => {
      console.warn('[Task Manager] Redis warning:', err.message);
    });

    activeClient = realClient;
  } catch (err) {
    console.warn('[Task Manager] Real Redis client init failed, using in-memory cache:', err.message);
    activeClient = fallbackCache;
  }
}

const redisProxy = {
  get isOpen() {
    return activeClient.isOpen ?? true;
  },
  connect: async () => {
    try {
      if (activeClient === fallbackCache) {
        return await fallbackCache.connect();
      }
      return await activeClient.connect();
    } catch (err) {
      console.warn('[Task Manager] Redis connection failed, falling back to in-memory cache:', err.message);
      activeClient = fallbackCache;
      return Promise.resolve();
    }
  },
  ping: async () => {
    try {
      return await activeClient.ping();
    } catch {
      return 'PONG';
    }
  },
  get: async (key) => {
    try {
      return await activeClient.get(key);
    } catch {
      return fallbackCache.get(key);
    }
  },
  setEx: async (key, seconds, val) => {
    try {
      return await activeClient.setEx(key, seconds, val);
    } catch {
      return fallbackCache.setEx(key, seconds, val);
    }
  },
  del: async (key) => {
    try {
      return await activeClient.del(key);
    } catch {
      return fallbackCache.del(key);
    }
  },
  quit: async () => {
    try {
      if (activeClient && activeClient.quit) {
        await activeClient.quit();
      }
    } catch {
      // ignore
    }
  },
  on: (event, handler) => {
    if (activeClient && activeClient.on) {
      activeClient.on(event, handler);
    }
  },
  getStats: () => ({
    hits: fallbackCache.hits,
    misses: fallbackCache.misses,
    cachedKeys: Array.from(fallbackCache.store.keys()),
    isFallback: activeClient === fallbackCache
  })
};

module.exports = redisProxy;
