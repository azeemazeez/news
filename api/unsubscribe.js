export default async function handler(req, res) {
  const email = req.query?.email;

  if (!email) {
    return res.status(400).send('Missing email');
  }

  try {
    // Find contact in audience
    const listRes = await fetch(
      `https://api.resend.com/audiences/${process.env.RESEND_AUDIENCE_ID}/contacts`,
      { headers: { Authorization: `Bearer ${process.env.RESEND_SUBSCRIBE_KEY}` } }
    );
    const { data: contacts } = await listRes.json();
    const contact = contacts.find(c => c.email === email);

    if (contact) {
      await fetch(
        `https://api.resend.com/audiences/${process.env.RESEND_AUDIENCE_ID}/contacts/${contact.id}`,
        {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${process.env.RESEND_SUBSCRIBE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ unsubscribed: true }),
        }
      );
    }
  } catch (err) {
    console.error('Unsubscribe error:', err.message);
  }

  // Always show confirmation page
  res.setHeader('Content-Type', 'text/html');
  res.status(200).send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Unsubscribed — The Nuus</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&display=swap" rel="stylesheet">
  <style>
    body { margin: 0; background: #fff; font-family: Inter, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
    .box { max-width: 420px; text-align: center; padding: 2rem; }
    h1 { font-size: 1.25rem; font-weight: 600; color: #1a1814; margin: 0 0 0.5rem; }
    p { font-size: 0.9rem; color: #6b6460; margin: 0 0 1.5rem; line-height: 1.6; }
    a { color: #6b33be; font-size: 0.85rem; }
  </style>
</head>
<body>
  <div class="box">
    <h1>You're unsubscribed</h1>
    <p>You won't receive any more emails from The Nuus.</p>
    <a href="https://thenuus.com">← Back to The Nuus</a>
  </div>
</body>
</html>`);
}
