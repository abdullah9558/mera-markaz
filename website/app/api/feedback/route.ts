import nodemailer from 'nodemailer';

export const runtime = 'nodejs';

const attempts = new Map<string, number[]>();
const windowMs = 60 * 60 * 1000;
const maxPerHour = 8;

function text(value: unknown, maximum: number) {
  return typeof value === 'string' ? value.trim().slice(0, maximum) : '';
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function allowed(ip: string) {
  const now = Date.now();
  const recent = (attempts.get(ip) ?? []).filter((time) => now - time < windowMs);
  if (recent.length >= maxPerHour) return false;
  recent.push(now);
  attempts.set(ip, recent);
  return true;
}

export async function POST(request: Request) {
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  if (!allowed(ip)) {
    return Response.json(
      { error: 'Too many feedback messages. Please try again later.' },
      { status: 429 },
    );
  }

  let payload: Record<string, unknown>;
  try {
    payload = (await request.json()) as Record<string, unknown>;
  } catch {
    return Response.json({ error: 'Invalid request.' }, { status: 400 });
  }

  const name = text(payload.name, 100);
  const phone = text(payload.phone, 30);
  const message = text(payload.message, 2000);
  const source = text(payload.source, 80) || 'Mera Markaz';
  if (message.length < 10) {
    return Response.json(
      { error: 'Please enter at least 10 characters.' },
      { status: 400 },
    );
  }
  if (phone && !/^[+0-9()\-\s]{5,30}$/.test(phone)) {
    return Response.json(
      { error: 'Please enter a valid phone number.' },
      { status: 400 },
    );
  }

  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const recipient = process.env.FEEDBACK_TO ?? 'muhammadabdullah589@gmail.com';
  if (!smtpUser || !smtpPass) {
    console.error('Feedback SMTP environment variables are missing.');
    return Response.json(
      { error: 'The feedback service is not configured yet.' },
      { status: 503 },
    );
  }

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST ?? 'smtp.gmail.com',
    port: Number(process.env.SMTP_PORT ?? 465),
    secure: Number(process.env.SMTP_PORT ?? 465) === 465,
    auth: { user: smtpUser, pass: smtpPass },
  });

  const identity = name || phone ? 'Provided' : 'Anonymous';
  try {
    await transporter.sendMail({
      from: `Mera Markaz Feedback <${smtpUser}>`,
      to: recipient,
      subject: `Mera Markaz feedback — ${identity}`,
      text: [
        `Source: ${source}`,
        `Name: ${name || 'Anonymous'}`,
        `Phone: ${phone || 'Not provided'}`,
        '',
        message,
      ].join('\n'),
      html: `
        <h2>Mera Markaz feedback</h2>
        <p><strong>Source:</strong> ${escapeHtml(source)}</p>
        <p><strong>Name:</strong> ${escapeHtml(name || 'Anonymous')}</p>
        <p><strong>Phone:</strong> ${escapeHtml(phone || 'Not provided')}</p>
        <hr />
        <p style="white-space:pre-wrap">${escapeHtml(message)}</p>
      `,
    });
    return Response.json({ delivered: true });
  } catch (error) {
    console.error('SMTP feedback delivery failed.', error);
    return Response.json(
      { error: 'Feedback could not be delivered. Please try again later.' },
      { status: 502 },
    );
  }
}
