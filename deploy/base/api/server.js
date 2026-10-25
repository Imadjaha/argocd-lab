const http = require('http');
http.createServer((req, res) => {
  res.setHeader('content-type', 'application/json');
  res.end(JSON.stringify({
    version: process.env.APP_VERSION, env: process.env.APP_ENV,
    pod: process.env.POD_NAME, time: new Date().toISOString()
  }));
}).listen(3000, () => console.log('api listening on 3000'));
