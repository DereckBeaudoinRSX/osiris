import { NextResponse } from 'next/server';
import type { NextRequest, NextFetchEvent } from 'next/server';

/**
 * Optional server-side page-view analytics.
 *
 * Disabled by default. It stays a pure pass-through unless BOTH `UMAMI_HOST`
 * and `UMAMI_WEBSITE_ID` are set, so a default deployment sends nothing
 * anywhere. There is no fallback website ID on purpose — an inherited one
 * would silently report a fork's traffic into someone else's dashboard.
 *
 * The visitor IP is forwarded only as `x-forwarded-for`, which is what Umami
 * uses to derive country and to salt its session hash; it does not persist the
 * raw address. The IP is deliberately NOT copied into any custom event
 * payload, which would store it verbatim.
 *
 * Delete this file outright if you never want analytics.
 */
const UMAMI_HOST = process.env.UMAMI_HOST;
const UMAMI_WEBSITE_ID = process.env.UMAMI_WEBSITE_ID;
const ANALYTICS_ENABLED = Boolean(UMAMI_HOST && UMAMI_WEBSITE_ID);

export function middleware(request: NextRequest, event: NextFetchEvent) {
  if (!ANALYTICS_ENABLED) return NextResponse.next();

  const ip =
    request.headers.get('cf-connecting-ip') ||
    request.headers.get('x-forwarded-for') ||
    '';

  const pageView = fetch(`${UMAMI_HOST!.replace(/\/$/, '')}/api/send`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': request.headers.get('user-agent') || 'OSIRIS',
      ...(ip ? { 'x-forwarded-for': ip } : {}),
    },
    body: JSON.stringify({
      type: 'event',
      payload: {
        website: UMAMI_WEBSITE_ID,
        hostname: request.nextUrl.hostname,
        url: request.nextUrl.pathname,
        referrer: request.headers.get('referer') || '',
        language: 'en-US',
        title: 'OSIRIS',
      },
    }),
  }).catch(() => {});

  event.waitUntil(pageView);
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
