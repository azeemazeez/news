import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

function formatDateLong(iso) {
  const [year, month, day] = iso.split('-').map(Number);
  return new Date(year, month - 1, day).toLocaleDateString('en-US', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });
}

export default async function handler(req, res) {
  const { date } = req.query;

  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return res.status(404).send('Not found');
  }

  const manifestPath = join(__dirname, '../public/data/manifest.json');
  if (!existsSync(manifestPath)) {
    return res.status(500).send('Server error');
  }

  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (!manifest.dates.includes(date)) {
    return res.status(404).send('Edition not found');
  }

  const label = formatDateLong(date);
  const [y, m, d] = date.split('-').map(Number);
  const dt = new Date(y, m - 1, d);
  const utilLabel = `${dt.toLocaleDateString('en-US', { weekday: 'long' })} · ${dt.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}`;
  const url = `https://thenuus.com/${date}`;
  const desc = `The Nuus — ${label}. The day's most significant stories, curated.`;
  const schema = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'NewsArticle',
    name: `The Nuus — ${label}`,
    url,
    isPartOf: { '@type': 'WebSite', name: 'The Nuus', url: 'https://thenuus.com' },
  });

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <title>The Nuus — ${label}</title>
  <meta name="description" content="${desc}">
  <link rel="canonical" href="${url}">

  <meta property="og:type" content="article">
  <meta property="og:url" content="${url}">
  <meta property="og:site_name" content="The Nuus">
  <meta property="og:title" content="The Nuus — ${label}">
  <meta property="og:description" content="${desc}">

  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="The Nuus — ${label}">
  <meta name="twitter:description" content="${desc}">

  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="manifest" href="/manifest.json">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Archivo:wght@500;600;700;800;900&family=Inter:wght@400;500;600;900&family=Newsreader:ital,opsz,wght@1,6..72,400&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/styles.css">
  <script type="application/ld+json">${schema}</script>
</head>
<body>

  <header class="masthead">
    <div class="util-bar">
      <span class="util-date">${utilLabel}</span>
      <span class="util-center">Today's 5-minute read</span>
      <div class="util-links">
        <a href="/#subscribe-form">Subscribe</a>
        <a href="/archive">Archive</a>
      </div>
    </div>
    <div class="masthead-block">
      <div class="eyebrow">
        <span class="eyebrow-rule"></span>
        <span class="eyebrow-label">Est. 2026 · Daily Edition</span>
        <span class="eyebrow-rule"></span>
      </div>
      <h1 class="site-name" id="site-name" role="link" tabindex="0">The Nuus</h1>
      <p class="masthead-tagline">Serving you bite-sized news, every day.</p>
    </div>
  </header>

  <main class="feed" id="feed">
    <div class="state-message"><p>Loading&hellip;</p></div>
  </main>

  <section class="subscribe-section">
    <form class="subscribe-form" id="subscribe-form">
      <label class="subscribe-label" for="subscribe-email">Get the daily digest in your inbox</label>
      <div class="subscribe-row">
        <input class="subscribe-input" id="subscribe-email" type="email" placeholder="you@example.com" required autocomplete="email">
        <button class="subscribe-btn" type="submit">Subscribe</button>
      </div>
      <p class="subscribe-msg" id="subscribe-msg" aria-live="polite"></p>
    </form>
  </section>

  <footer class="footer">
    <p>The Nuus: Curated daily</p>
    <nav class="footer-nav">
      <a href="/archive">Archive</a>
      <a href="/about">About</a>
    </nav>
  </footer>

  <script src="/app.js"></script>
  <script>
    document.getElementById('subscribe-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('subscribe-email').value;
      const msg = document.getElementById('subscribe-msg');
      const btn = e.target.querySelector('button');
      btn.disabled = true;
      btn.textContent = 'Subscribing…';
      msg.textContent = '';
      msg.className = 'subscribe-msg';
      try {
        const res = await fetch('/api/subscribe', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email }),
        });
        let data = {};
        try { data = await res.json(); } catch {}
        if (res.ok) {
          msg.textContent = 'You\'re subscribed. See you tomorrow.';
          msg.classList.add('subscribe-msg--success');
          e.target.reset();
        } else {
          throw new Error(data.error || \`Error \${res.status} — please try again\`);
        }
      } catch (err) {
        msg.textContent = err.message;
        msg.classList.add('subscribe-msg--error');
      } finally {
        btn.disabled = false;
        btn.textContent = 'Subscribe';
      }
    });
  </script>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 's-maxage=86400, stale-while-revalidate');
  return res.status(200).send(html);
}
