const SITE_NAME = 'The Nuus';

let manifest = { dates: [] };
let currentDate = null;

function formatDate(iso) {
  const [year, month, day] = iso.split('-').map(Number);
  const d = new Date(year, month - 1, day);
  return d.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
}

function strip(str) {
  return (str || '').replace(/\*\*/g, '');
}

function renderStory(story) {
  return `
    <article class="story">
      <p class="story-line"><strong>${strip(story.intro)}</strong> ${strip(story.body)} <a class="story-link" href="${story.url}" target="_blank" rel="noopener noreferrer">${strip(story.link_text)}</a></p>
    </article>
  `;
}

function renderFeed(data) {
  if (!data || !data.stories || data.stories.length === 0) {
    return `<div class="state-message"><h2>No stories available for this date.</h2></div>`;
  }
  return data.stories.map(renderStory).join('');
}

function updateCanonical(date) {
  const el = document.querySelector('link[rel="canonical"]');
  if (!el) return;
  el.href = (date === manifest.dates[0])
    ? 'https://thenuus.com/'
    : `https://thenuus.com/${date}`;
}

async function loadDay(date) {
  currentDate = date;
  document.getElementById('feed').innerHTML = '<div class="state-message"><p>Loading...</p></div>';
  updateCanonical(date);

  try {
    const res = await fetch(`/data/${date}.json`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    document.getElementById('feed').innerHTML = renderFeed(data);
  } catch (e) {
    document.getElementById('feed').innerHTML = `
      <div class="state-message">
        <h2>Could not load ${date}</h2>
        <p>The data file may not exist yet. Run <code>npm run fetch</code> to generate it.</p>
      </div>`;
  }
}

async function init() {
  // Render shell immediately
  document.getElementById('site-name').textContent = SITE_NAME;

  try {
    const res = await fetch('/data/manifest.json?t=' + Date.now());
    if (res.ok) manifest = await res.json();
  } catch (e) {
    // no manifest yet
  }

  if (manifest.dates.length === 0) {
    document.getElementById('feed').innerHTML = `
      <div class="state-message">
        <h2>No news yet</h2>
        <p>Run <code>npm run fetch</code> to pull today's news, or wait for the daily cron to run.</p>
      </div>`;
    return;
  }

  // Check if URL has a date path (/YYYY-MM-DD) or legacy query param (?d=)
  const pathDate = window.location.pathname.match(/^\/(\d{4}-\d{2}-\d{2})$/)?.[1];
  const paramDate = new URLSearchParams(window.location.search).get('d');
  const reqDate = pathDate || paramDate;
  const startDate = (reqDate && manifest.dates.includes(reqDate)) ? reqDate : manifest.dates[0];

  await loadDay(startDate);
}

window.addEventListener('popstate', () => {
  const pathDate = window.location.pathname.match(/^\/(\d{4}-\d{2}-\d{2})$/)?.[1];
  const paramDate = new URLSearchParams(window.location.search).get('d');
  const d = pathDate || paramDate;
  if (d && manifest.dates.includes(d)) loadDay(d);
});

document.addEventListener('DOMContentLoaded', () => {
  const utilDate = document.getElementById('util-date');
  if (utilDate) {
    const now = new Date();
    const weekday = now.toLocaleDateString('en-US', { weekday: 'long' });
    const rest = now.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    utilDate.textContent = `${weekday} · ${rest}`;
  }

  document.getElementById('site-name').addEventListener('click', () => {
    if (manifest.dates.length > 0) {
      history.pushState({}, '', '/');
      loadDay(manifest.dates[0]);
    }
  });
  init();
});
