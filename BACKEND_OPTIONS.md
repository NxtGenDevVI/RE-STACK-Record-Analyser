# Backend Options for Audit Logging

This document outlines three production-ready approaches to add audit logging for tracking domain analyses.

## Option 1: Serverless Functions (Recommended for GitHub Pages)

### Using Cloudflare Workers (Free tier: 100,000 requests/day)

**Benefits:**
- No server management
- Global edge deployment
- Free tier is generous
- Easy integration with existing static site
- Can store in Cloudflare D1 (SQLite) or KV storage

**Setup:**
1. Create Cloudflare Workers account
2. Deploy worker endpoint
3. Use Cloudflare D1 for SQLite database

**Example Worker Code:**
```javascript
export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'Content-Type',
        }
      });
    }

    if (request.method === 'POST') {
      const data = await request.json();
      
      await env.DB.prepare(
        'INSERT INTO audit_log (domain, timestamp, ip_address, results) VALUES (?, ?, ?, ?)'
      ).bind(
        data.domain,
        new Date().toISOString(),
        request.headers.get('CF-Connecting-IP'),
        JSON.stringify(data.results)
      ).run();

      return new Response(JSON.stringify({ success: true }), {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'application/json'
        }
      });
    }

    return new Response('Method not allowed', { status: 405 });
  }
};
```

**Database Schema:**
```sql
CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  domain TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  ip_address TEXT,
  results TEXT,
  user_agent TEXT
);

CREATE INDEX idx_domain ON audit_log(domain);
CREATE INDEX idx_timestamp ON audit_log(timestamp);
```

**Cost:** Free up to 100k requests/day, then $5/month for 10M requests

---

## Option 2: Vercel Serverless Functions

**Benefits:**
- Easy GitHub integration
- Can host entire app + backend
- Free tier: 100GB bandwidth, 100 hours execution
- Built-in analytics

**Setup:**
1. Move project to Vercel
2. Create API routes in `/api` folder
3. Use Vercel Postgres or external database

**Example API Route (`/api/log.js`):**
```javascript
import { sql } from '@vercel/postgres';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { domain, results } = req.body;
  const ipAddress = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
  
  try {
    await sql`
      INSERT INTO audit_log (domain, timestamp, ip_address, results, user_agent)
      VALUES (${domain}, NOW(), ${ipAddress}, ${JSON.stringify(results)}, ${req.headers['user-agent']})
    `;
    
    res.status(200).json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Database error' });
  }
}
```

**Cost:** Free tier generous, Pro is $20/month

---

## Option 3: Simple Node.js Backend (Traditional)

**Benefits:**
- Full control
- Can run on any VPS
- Use any database
- More complex features possible

**Tech Stack:**
- Express.js
- PostgreSQL or MySQL
- Deployed on Railway, Render, or DigitalOcean

**Example Express Server:**
```javascript
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

app.use(cors({
  origin: ['https://yourusername.github.io', 'http://localhost']
}));
app.use(express.json());

app.post('/api/log', async (req, res) => {
  const { domain, results } = req.body;
  const ipAddress = req.ip;
  const userAgent = req.get('user-agent');
  
  try {
    await pool.query(
      'INSERT INTO audit_log (domain, timestamp, ip_address, results, user_agent) VALUES ($1, NOW(), $2, $3, $4)',
      [domain, ipAddress, JSON.stringify(results), userAgent]
    );
    res.json({ success: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to log' });
  }
});

app.get('/api/stats', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT domain, COUNT(*) as count FROM audit_log GROUP BY domain ORDER BY count DESC LIMIT 10'
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
```

**Cost:** $5-10/month (Railway/Render free tier available)

---

## Recommendation

**For your expo use case: Cloudflare Workers**

Reasons:
1. **Reliability**: Global edge network, 99.99% uptime
2. **Speed**: Responses in <50ms globally
3. **Cost**: Free tier covers expo usage easily
4. **Simple**: No server to manage
5. **Integration**: Works perfectly with GitHub Pages
6. **Privacy**: Can add your own analytics without third-party trackers

---

## Frontend Integration

Add to `app.js` after successful DNS check:

```javascript
async function logAudit(domain, results) {
  try {
    await fetch('https://your-worker.workers.dev/log', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        domain,
        results: {
          spf: results.spfResult,
          dkim: results.dkimResults,
          dmarc: results.dmarcResult
        }
      })
    });
  } catch (error) {
    console.error('Audit logging failed:', error);
  }
}
```

Call in `handleCheck()` after displaying results:
```javascript
displayResults(spfResult, dkimResults, dmarcResult);
await logAudit(domain, { spfResult, dkimResults, dmarcResult });
```

---

## Privacy Considerations

**GDPR Compliance:**
- Domain names may be personal data
- Add privacy notice: "Domain checks are logged for analytics"
- Provide data retention policy (e.g., 90 days)
- Allow users to opt-out

**Minimal Logging:**
- Only log: domain, timestamp, check results
- Don't log: email addresses, names, sensitive data
- Hash IP addresses for privacy

**Data Retention:**
```sql
-- Auto-delete old logs (run daily)
DELETE FROM audit_log WHERE timestamp < datetime('now', '-90 days');
```

---

## Next Steps

1. Choose backend approach (recommend Cloudflare Workers)
2. Set up database schema
3. Deploy backend endpoint
4. Integrate logging into frontend
5. Add privacy notice to UI
6. Build admin dashboard (optional)
