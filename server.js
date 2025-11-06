const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.VERSION || '1.0.0';
const COLOR = process.env.COLOR || 'BLUE';

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    version: VERSION,
    color: COLOR,
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Application info endpoint
app.get('/info', (req, res) => {
  res.json({
    name: 'Blue-Green Deployment App',
    version: VERSION,
    environment: COLOR,
    hostname: require('os').hostname(),
    port: PORT
  });
});

// Main endpoint
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Blue-Green Deployment Demo</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin: 50px;
            background-color: ${COLOR === 'BLUE' ? '#e6f3ff' : '#e6ffe6'};
          }
          .container {
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
          }
          h1 { color: ${COLOR === 'BLUE' ? '#0066cc' : '#008800'}; }
          .status {
            font-size: 20px;
            margin: 20px 0;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🟩 Blue-Green Deployment Demo 🟦</h1>
          <div class="status">
            <p>Current Environment: <strong>${COLOR}</strong></p>
            <p>Version: <strong>${VERSION}</strong></p>
            <p>Server: <strong>${require('os').hostname()}</strong></p>
          </div>
          <hr>
          <p>Health Check: <a href="/health">/health</a></p>
          <p>Info: <a href="/info">/info</a></p>
        </div>
      </body>
    </html>
  `);
});

// Ready endpoint for Kubernetes
app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${COLOR}`);
  console.log(`Version: ${VERSION}`);
});