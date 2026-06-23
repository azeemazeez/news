import Anthropic from '@anthropic-ai/sdk';
import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const dataDir = join(__dirname, '../public/data');
const client = new Anthropic();

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

async function curateWithClaude(stories) {
  const storyList = stories
    .slice(0, 120)
    .map((s, i) =>
      `${i + 1}. [${s.source}${s.score ? `, score:${s.score}` : ''}] ${s.title}\n   ${s.url}`
    )
    .join('\n');

  const message = await client.messages.create({
    model: 'claude-opus-4-8',
    max_tokens: 4096,
    messages: [
      {
        role: 'user',
        content: `You are the editor of a sharp, intelligent daily news digest — like The Morning News or Arts & Letters Daily. Your readers are curious, educated generalists who want to understand the world.

From the stories below (collected in the last 24 hours), select exactly 12 that an intelligent general audience would most want to know about.

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
      "intro": "2–5 word bold hook, no trailing punctuation",
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
  console.log('Fetching news sources...');

  const [hn, worldnews, technology, science, uplift] = await Promise.allSettled([
    fetchHackerNews(),
    fetchReddit('worldnews'),
    fetchReddit('technology'),
    fetchReddit('science'),
    fetchReddit('UpliftingNews'),
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
    ...newsApiStories,
  ];

  const seen = new Set();
  const unique = allStories.filter(s => {
    const key = s.url;
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  console.log(`Collected ${unique.length} unique stories, curating with Claude...`);

  const curated = await curateWithClaude(unique);

  const date = new Date().toISOString().split('T')[0];
  const output = {
    date,
    generated_at: new Date().toISOString(),
    stories: curated.stories,
  };

  if (!existsSync(dataDir)) mkdirSync(dataDir, { recursive: true });

  writeFileSync(join(dataDir, `${date}.json`), JSON.stringify(output, null, 2));
  console.log(`Wrote public/data/${date}.json (${curated.stories.length} stories)`);

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
  const today = new Date().toISOString().split('T')[0];
  const dateUrls = manifest.dates.map(d => `
  <url>
    <loc>${siteUrl}/?d=${d}</loc>
    <lastmod>${d}</lastmod>
    <changefreq>never</changefreq>
  </url>`).join('');

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${siteUrl}/</loc>
    <lastmod>${today}</lastmod>
    <changefreq>daily</changefreq>
  </url>
  <url>
    <loc>${siteUrl}/archive</loc>
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
