export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type DataPoint = {
  seriesKey: string;
  value: number;
  unit: string;
  sourceName: string;
  sourceReference: string;
  effectiveAt: string;
  retrievedAt: string;
  previousValue?: number;
  configVersion: string;
};

const currencies = ['USD', 'GBP', 'EUR', 'AED', 'SAR', 'CAD', 'AUD', 'QAR', 'KWD', 'OMR'] as const;

async function fetchText(url: string) {
  const response = await fetch(url, {
    headers: { Accept: 'text/html,application/json' },
    signal: AbortSignal.timeout(8_000),
    next: { revalidate: 3_600 },
  });
  if (!response.ok) throw new Error(`${url} returned ${response.status}`);
  return response.text();
}

function plainText(html: string) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

function numberAfter(text: string, expression: RegExp) {
  const match = text.match(expression);
  if (!match) return null;
  const value = Number(match[1].replaceAll(',', ''));
  return Number.isFinite(value) && value > 0 ? value : null;
}

async function exchangeRates(retrievedAt: string): Promise<DataPoint[]> {
  const url = 'https://open.er-api.com/v6/latest/USD';
  const response = await fetch(url, {
    headers: { Accept: 'application/json' },
    signal: AbortSignal.timeout(8_000),
    next: { revalidate: 3_600 },
  });
  if (!response.ok) throw new Error(`Exchange feed returned ${response.status}`);
  const payload = (await response.json()) as {
    result?: string;
    time_last_update_utc?: string;
    rates?: Record<string, number>;
  };
  if (payload.result !== 'success' || !payload.rates?.PKR) return [];
  const effectiveAt = new Date(payload.time_last_update_utc ?? retrievedAt).toISOString();
  const pkrPerUsd = payload.rates.PKR;
  return currencies.flatMap((currency) => {
    const unitsPerUsd = payload.rates?.[currency];
    if (!unitsPerUsd || unitsPerUsd <= 0) return [];
    return [{
      seriesKey: `${currency.toLowerCase()}_pkr`,
      value: pkrPerUsd / unitsPerUsd,
      unit: 'PKR',
      sourceName: 'ExchangeRate-API open feed',
      sourceReference: url,
      effectiveAt,
      retrievedAt,
      configVersion: 'exchange-open-v1',
    }];
  });
}

async function sbpIndicators(retrievedAt: string): Promise<DataPoint[]> {
  const url = 'https://www.sbp.org.pk/';
  const text = plainText(await fetchText(url));
  const points: DataPoint[] = [];
  const add = (seriesKey: string, value: number | null, unit: string) => {
    if (value == null) return;
    points.push({
      seriesKey,
      value,
      unit,
      sourceName: 'State Bank of Pakistan',
      sourceReference: url,
      effectiveAt: retrievedAt,
      retrievedAt,
      configVersion: 'sbp-home-v1',
    });
  };
  add('sbp_policy_rate', numberAfter(text, /SBP Policy Rate\s*([0-9.]+)\s*%/i), '%');
  add('forex_reserves', numberAfter(text, /Total Reserves\s*([0-9,.]+)/i), 'USD million');
  const kibor = text.match(/3\s*-?\s*M\s*([0-9.]+)\s*([0-9.]+)/i);
  if (kibor) {
    const bid = Number(kibor[1]);
    const offer = Number(kibor[2]);
    add('kibor_3m', Number.isFinite(bid + offer) ? (bid + offer) / 2 : null, '%');
  }
  return points;
}

async function pbsInflation(retrievedAt: string): Promise<DataPoint[]> {
  const url = 'https://www.pbs.gov.pk/price-statistics/';
  const text = plainText(await fetchText(url));
  const value = numberAfter(text, /CPI National[^.]{0,180}?(?:increased|inflation)[^0-9]{0,30}([0-9.]+)\s*%/i);
  if (value == null) return [];
  return [{
    seriesKey: 'inflation_cpi',
    value,
    unit: '%',
    sourceName: 'Pakistan Bureau of Statistics',
    sourceReference: url,
    effectiveAt: retrievedAt,
    retrievedAt,
    configVersion: 'pbs-cpi-v1',
  }];
}

export async function GET() {
  const retrievedAt = new Date().toISOString();
  const settled = await Promise.allSettled([
    exchangeRates(retrievedAt),
    sbpIndicators(retrievedAt),
    pbsInflation(retrievedAt),
  ]);
  const data = settled.flatMap((result) => result.status === 'fulfilled' ? result.value : []);
  const unavailable = settled
    .map((result, index) => result.status === 'rejected' ? ['exchange', 'sbp', 'pbs'][index] : null)
    .filter(Boolean);
  return Response.json(
    { data, retrievedAt, unavailable },
    { headers: {
      'Cache-Control': 'public, s-maxage=1800, stale-while-revalidate=86400',
      'Access-Control-Allow-Origin': '*',
    } },
  );
}
