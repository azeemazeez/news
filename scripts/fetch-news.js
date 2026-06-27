import Anthropic from '@anthropic-ai/sdk';
import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const dataDir = join(__dirname, '../public/data');
const publicDir = join(__dirname, '../public');
const client = new Anthropic();

function formatDateLong(iso) {
  const [year, month, day] = iso.split('-').map(Number);
  return new Date(year, month - 1, day).toLocaleDateString('en-US', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });
}

function generateDatePage(date) {
  const label = formatDateLong(date);
  const url = `https://thenuus.com/${date}`;
  const desc = `The Nuus — ${label}. The day's most significant stories, curated.`;
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
  <link href="https://fonts.googleapis.com/css2?family=Cal+Sans&family=Inter:wght@400;500;600;900&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/styles.css">
  <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","name":"The Nuus — ${label}","url":"${url}","isPartOf":{"@type":"WebSite","name":"The Nuus","url":"https://thenuus.com"}}</script>
</head>
<body>

  <header class="masthead">
    <div class="masthead-inner">
      <h1 class="site-name" id="site-name" role="link" tabindex="0">The Nuus</h1>
    </div>
  </header>

  <div class="date-bar">
    <span class="date-display" id="date-display">Loading&hellip;</span>
  </div>

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
  writeFileSync(join(publicDir, `${date}.html`), html);
  console.log(`Wrote public/${date}.html`);
}

async function fetchRSS(url, sourceName) {
  const res = await fetch(url, { headers: { 'User-Agent': 'daily-news-portal/1.0' } });
  const xml = await res.text();

  const items = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  let match;

  while ((match = itemRegex.exec(xml)) !== null) {
    const block = match[1];
    const extract = tag => {
      const cdataMatch = block.match(new RegExp(`<${tag}[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\\/${tag}>`));
      const plainMatch = block.match(new RegExp(`<${tag}[^>]*>([^<]*)<\\/${tag}>`));
      return (cdataMatch?.[1] || plainMatch?.[1] || '').trim();
    };

    const title = extract('title');
    const link = extract('link') || extract('guid');

    if (title && link && link.startsWith('http')) {
      items.push({ title, url: link, source: sourceName, score: 0 });
    }
  }

  return items;
}

async function fetchHackerNews() {
  const res = await fetch('https://hacker-news.firebaseio.com/v0/topstories.json');
  const ids = await res.json();
  const top60 = ids.slice(0, 60);

  const stories = await Promise.allSettled(
    top60.map(id =>
      fetch(`https://hacker-news.firebaseio.com/v0/item/${id}.json`).then(r => r.json())
    )
  );

  return stories
    .filter(r => r.status === 'fulfilled' && r.value?.url && r.value?.score > 30)
    .map(r => ({
      title: r.value.title,
      url: r.value.url,
      source: 'Hacker News',
      score: r.value.score,
    }));
}

async function fetchReddit(subreddit) {
  const res = await fetch(
    `https://www.reddit.com/r/${subreddit}/top.json?t=day&limit=25`,
    { headers: { 'User-Agent': 'daily-news-portal/1.0' } }
  );
  const data = await res.json();
  if (!data?.data?.children) return [];
  return data.data.children
    .filter(p => p.data.score > 100 && !p.data.stickied)
    .map(p => ({
      title: p.data.title,
      url: p.data.url.startsWith('/r/') ? `https://reddit.com${p.data.url}` : p.data.url,
      source: `r/${subreddit}`,
      score: p.data.score,
    }));
}

async function fetchNewsAPI() {
  if (!process.env.NEWS_API_KEY) return [];
  const res = await fetch(
    `https://newsapi.org/v2/top-headlines?language=en&pageSize=30&apiKey=${process.env.NEWS_API_KEY}`
  );
  const data = await res.json();
  return (data.articles || [])
    .filter(a => a.title && a.url && !a.title.includes('[Removed]'))
    .map(a => ({
      title: a.title,
      url: a.url,
      source: a.source?.name || 'NewsAPI',
      score: 0,
    }));
}

async function curateWithClaude(stories, previousStories = []) {
  const storyList = stories
    .slice(0, 120)
    .map((s, i) =>
      `${i + 1}. [${s.source}${s.score ? `, score:${s.score}` : ''}] ${s.title}\n   ${s.url}`
    )
    .join('\n');

  const previousBlock = previousStories.length > 0
    ? `\n\nYESTERDAY'S STORIES (already published — skip these topics and anything closely related):\n${previousStories.map(s => `- ${s.intro} ${s.body}`).join('\n')}\n`
    : '';

  const message = await client.messages.create({
    model: 'claude-opus-4-8',
    max_tokens: 4096,
    messages: [
      {
        role: 'user',
        content: `You are the editor of a sharp, intelligent daily news digest — like The Morning News or Arts & Letters Daily. Your readers are curious, educated generalists who want to understand the world.

From the stories below (collected in the last 24 hours), select exactly 15 that an intelligent general audience would most want to know about.${previousBlock}

Prioritize stories that:
- Have broad significance or represent a meaningful shift
- Are surprising, counterintuitive, or reveal something most people don't know yet
- Illuminate important scientific, technological, political, or cultural developments
- Have implications that will matter months or years from now

Skip: sports scores, celebrity gossip, stock price moves, local crime, product announcements, earnings reports, pure political horse-race coverage.

Stories:
${storyList}

Each entry should read as a single flowing paragraph in this style:
  **intro** body link_text / Source

Where:
- intro is a bold 2–5 word hook (no trailing punctuation)
- body is 1–2 sentences that flow naturally from intro, ending just before the link_text
- link_text is a 3–8 word phrase (with trailing period) that concludes the entry and will be hyperlinked

Example style: intro="H5N1 reaches every continent", body="after Australia confirmed its first case — raising the risk of mutations that could enable", link_text="human-to-human transmission."

Return ONLY valid JSON, no markdown, no other text:
{
  "stories": [
    {
      "intro": "2–5 word hook, no trailing punctuation, no markdown",
      "body": "Prose continuing from intro, 1–2 sentences, ends with a space before the link phrase.",
      "link_text": "3–8 word concluding phrase with trailing period, will be hyperlinked.",
      "url": "original URL unchanged",
      "source": "source name"
    }
  ]
}`,
      },
    ],
  });

  const text = message.content[0].text.trim();
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error('Claude returned non-JSON response');
  return JSON.parse(jsonMatch[0]);
}

async function main() {
  const dateIdx = process.argv.indexOf('--date');
  const dateArg = dateIdx !== -1 ? process.argv[dateIdx + 1] : null;
  if (dateArg && !/^\d{4}-\d{2}-\d{2}$/.test(dateArg)) {
    console.error('Invalid date format. Use --date YYYY-MM-DD');
    process.exit(1);
  }

  console.log('Fetching news sources...');

  const [hn, worldnews, technology, science, uplift, bbc, nyt] = await Promise.allSettled([
    fetchHackerNews(),
    fetchReddit('worldnews'),
    fetchReddit('technology'),
    fetchReddit('science'),
    fetchReddit('UpliftingNews'),
    fetchRSS('https://feeds.bbci.co.uk/news/rss.xml', 'BBC News'),
    fetchRSS('https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml', 'New York Times'),
  ]);

  let newsApiStories = [];
  try {
    newsApiStories = await fetchNewsAPI();
  } catch (e) {
    console.warn('NewsAPI fetch failed:', e.message);
  }

  const allStories = [
    ...(hn.status === 'fulfilled' ? hn.value : []),
    ...(worldnews.status === 'fulfilled' ? worldnews.value : []),
    ...(technology.status === 'fulfilled' ? technology.value : []),
    ...(science.status === 'fulfilled' ? science.value : []),
    ...(uplift.status === 'fulfilled' ? uplift.value : []),
    ...(bbc.status === 'fulfilled' ? bbc.value : []),
    ...(nyt.status === 'fulfilled' ? nyt.value : []),
    ...newsApiStories,
  ];

  const PAYWALLED = ['washingtonpost.com', 'wsj.com', 'ft.com', 'thetimes.co.uk'];

  const seen = new Set();
  const unique = allStories.filter(s => {
    const key = s.url;
    if (!key || seen.has(key)) return false;
    if (PAYWALLED.some(domain => key.includes(domain))) return false;
    seen.add(key);
    return true;
  });

  console.log(`Collected ${unique.length} unique stories, curating with Claude...`);

  // Load yesterday's stories to avoid repeats
  const date = dateArg || new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString().split('T')[0];
  const [year, month, day] = date.split('-').map(Number);
  const yesterday = new Date(Date.UTC(year, month - 1, day - 1)).toISOString().split('T')[0];
  const yesterdayPath = join(dataDir, `${yesterday}.json`);
  let previousStories = [];
  if (existsSync(yesterdayPath)) {
    try {
      previousStories = JSON.parse(readFileSync(yesterdayPath, 'utf8')).stories || [];
      console.log(`Loaded ${previousStories.length} stories from ${yesterday} for dedup`);
    } catch {}
  }

  let curated;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      curated = await curateWithClaude(unique, previousStories);
      break;
    } catch (err) {
      console.warn(`Claude API attempt ${attempt} failed: ${err.message}`);
      if (attempt === 3) throw err;
      await new Promise(r => setTimeout(r, attempt * 5000));
    }
  }

  const output = {
    date,
    generated_at: new Date().toISOString(),
    stories: curated.stories,
  };

  if (!existsSync(dataDir)) mkdirSync(dataDir, { recursive: true });

  writeFileSync(join(dataDir, `${date}.json`), JSON.stringify(output, null, 2));
  console.log(`Wrote public/data/${date}.json (${curated.stories.length} stories)`);

  generateDatePage(date);

  const manifestPath = join(dataDir, 'manifest.json');
  let manifest = { dates: [] };
  if (existsSync(manifestPath)) {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  }
  if (!manifest.dates.includes(date)) {
    manifest.dates.unshift(date);
    manifest.dates.sort((a, b) => b.localeCompare(a));
  }
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  console.log('Updated manifest.json');

  const siteUrl = 'https://thenuus.com';
  const today = new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString().split('T')[0];

  const dateUrls = manifest.dates.map(d => `  <url>
    <loc>${siteUrl}/${d}</loc>
    <lastmod>${d}</lastmod>
    <changefreq>never</changefreq>
  </url>`).join('\n');

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${siteUrl}/</loc>
    <lastmod>${today}</lastmod>
    <changefreq>daily</changefreq>
  </url>
  <url>
    <loc>${siteUrl}/archive</loc>
    <lastmod>${today}</lastmod>
    <changefreq>daily</changefreq>
  </url>
  <url>
    <loc>${siteUrl}/about</loc>
    <changefreq>monthly</changefreq>
  </url>
${dateUrls}
</urlset>`;

  writeFileSync(join(__dirname, '../public/sitemap.xml'), sitemap);
  console.log('Updated sitemap.xml');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
