const { test } = require('node:test');
const assert = require('node:assert');
const http = require('http');

test('health endpoint returns 200', async () => {
  const { server } = require('./index.js');
  
  // Wait for server to start
  await new Promise(resolve => setTimeout(resolve, 100));
  
  const response = await new Promise((resolve, reject) => {
    const req = http.request({
      hostname: 'localhost',
      port: process.env.PORT || 8080,
      path: '/health',
      method: 'GET'
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, data: JSON.parse(data) }));
    });
    req.on('error', reject);
    req.end();
  });

  assert.strictEqual(response.status, 200);
  assert.strictEqual(response.data.status, 'healthy');
  
  server.close();
});
