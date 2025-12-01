const http = require('http');

const port = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  const timestamp = new Date().toISOString();
  
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp }));
    return;
  }

  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>DevOps Test App</title>
          <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
            h1 { color: #0078d4; }
            .info { background: #f0f0f0; padding: 15px; border-radius: 5px; }
          </style>
        </head>
        <body>
          <h1>🚀 DevOps Test App</h1>
          <p>Successfully deployed to Azure App Service!</p>
          <div class="info">
            <p><strong>Server Time:</strong> ${timestamp}</p>
            <p><strong>Node Version:</strong> ${process.version}</p>
            <p><strong>Environment:</strong> ${process.env.NODE_ENV || 'development'}</p>
          </div>
        </body>
      </html>
    `);
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not Found' }));
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

module.exports = { server };
