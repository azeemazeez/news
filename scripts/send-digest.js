import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RESEND_API_KEY = process.env.RESEND_SUBSCRIBE_KEY;
const RESEND_AUDIENCE_ID = process.env.RESEND_AUDIENCE_ID;
const FROM = 'The Nuus <hi@thenuus.com>';
const SITE_URL = 'https://thenuus.com';

function formatDate(iso) {
  const [year, month, day] = iso.split('-').map(Number);
  return new Date(year, month - 1, day).toLocaleDateString('en-US', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });
}

function buildHtml(stories, date) {
  const dateLabel = formatDate(date);

  const articles = stories.map(s => `
    <tr>
      <td style="padding: 16px 0; border-bottom: 1px solid #ede9e0;">
        <p style="margin: 0; font-size: 17px; line-height: 1.7; color: #1a1814; font-family: Inter, -apple-system, sans-serif;">
          <strong>${s.intro}</strong> ${s.body}
          <a href="${s.url}" style="color: #6b33be; text-decoration: underline;">${s.link_text}</a>
        </p>
      </td>
    </tr>`).join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>The Nuus — ${dateLabel}</title>
</head>
<body style="margin:0;padding:0;background:#ffffff;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#ffffff;">
    <tr>
      <td align="center" style="padding: 0 16px;">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;">

          <!-- Top border -->
          <tr><td style="height: 8px; background: #6b33be; border-radius: 0 0 2px 2px;"></td></tr>

          <!-- Header -->
          <tr>
            <td style="padding: 32px 0 24px;">
              <p style="margin:0;font-size:40px;font-weight:900;color:#6b33be;font-family:Inter,-apple-system,sans-serif;letter-spacing:-0.02em;">The Nuus</p>
              <p style="margin:6px 0 0;font-size:11px;font-weight:500;color:#a09890;text-transform:uppercase;letter-spacing:0.06em;font-family:Inter,-apple-system,sans-serif;">${dateLabel}</p>
            </td>
          </tr>

          <!-- Divider -->
          <tr><td style="height:1px;background:#ede9e0;"></td></tr>

          <!-- Articles -->
          <tr>
            <td>
              <table width="100%" cellpadding="0" cellspacing="0">
                ${articles}
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 0 40px; text-align: center;">
              <p style="margin:0;font-size:11px;color:#c0b8b0;font-family:Inter,-apple-system,sans-serif;text-transform:uppercase;letter-spacing:0.04em;">
                <a href="${SITE_URL}" style="color:#c0b8b0;text-decoration:none;">thenuus.com</a>
                &nbsp;&middot;&nbsp;
                <a href="${SITE_URL}/api/unsubscribe?email={{EMAIL}}" style="color:#c0b8b0;text-decoration:none;">Unsubscribe</a>
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

async function main() {
  const date = new Date().toISOString().split('T')[0];
  const dataPath = join(__dirname, '../public/data', `${date}.json`);

  if (!existsSync(dataPath)) {
    console.error(`No data file found for ${date} — skipping digest`);
    process.exit(0);
  }

  const { stories } = JSON.parse(readFileSync(dataPath, 'utf8'));
  const dateLabel = formatDate(date);
  const html = buildHtml(stories, date);

  // Fetch subscribers from audience
  const contactsRes = await fetch(
    `https://api.resend.com/audiences/${RESEND_AUDIENCE_ID}/contacts`,
    { headers: { Authorization: `Bearer ${RESEND_API_KEY}` } }
  );

  if (!contactsRes.ok) {
    const err = await contactsRes.json();
    throw new Error(`Failed to fetch contacts: ${JSON.stringify(err)}`);
  }

  const contactsBody = await contactsRes.json();
  console.log('Contacts API response:', JSON.stringify(contactsBody));
  const contacts = contactsBody.data || [];
  const active = contacts.filter(c => !c.unsubscribed);
  console.log(`Total contacts: ${contacts.length}, active: ${active.length}`);

  // Send individual transactional emails
  let sent = 0;
  for (let i = 0; i < active.length; i++) {
    await new Promise(r => setTimeout(r, 1000));
    const contact = active[i];
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: FROM,
        to: contact.email,
        subject: `The Nuus — ${dateLabel}`,
        html: html.replace('{{EMAIL}}', encodeURIComponent(contact.email)),
        headers: {
          'List-Unsubscribe': `<https://thenuus.com/api/unsubscribe?email=${encodeURIComponent(contact.email)}>`,
          'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
        },
      }),
    });

    if (res.ok) {
      sent++;
    } else {
      const err = await res.json();
      console.error(`Failed to send to ${contact.email}:`, err.message);
    }

  }

  console.log(`Digest sent to ${sent}/${active.length} subscribers for ${date}`);

  // Notify owner
  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: FROM,
      to: 'hi@azeem.me',
      subject: `The Nuus ran — ${dateLabel}`,
      text: `Today's digest was sent successfully.\n\nSent: ${sent}/${active.length} subscribers`,
    }),
  });
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
