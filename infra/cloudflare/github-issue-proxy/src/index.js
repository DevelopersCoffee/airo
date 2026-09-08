/**
 * GitHub issue proxy for Airo's in-app bug reporter.
 *
 * Contract (must match packages/core_data/lib/src/bug_report/github_issue_service.dart):
 *   POST /            header: X-API-Key: <PROXY_API_KEY>
 *                      body:   {"title": string, "body": string, "labels": string[]}
 *   response:          {"number": number, "html_url": string, "title": string}
 *
 * The GitHub PAT never reaches the app: it lives only as this Worker's
 * GITHUB_TOKEN secret. The app instead carries the PROXY_API_KEY, which
 * gates casual abuse (a compiled APK can still be decompiled to read it,
 * so this is a soft gate, not a real secret boundary) -- reporters never
 * need a GitHub account, since the Worker files the issue on their behalf.
 */

const MAX_TITLE_LENGTH = 256;
const MAX_BODY_LENGTH = 60000;
const MAX_LABELS = 10;
const MAX_LABEL_LENGTH = 64;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
};

function jsonResponse(body, status, extraHeaders) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
      ...(extraHeaders || {}),
    },
  });
}

function validatePayload(payload) {
  if (typeof payload !== 'object' || payload === null) {
    return 'Request body must be a JSON object.';
  }
  if (typeof payload.title !== 'string' || payload.title.trim().length === 0) {
    return '"title" is required.';
  }
  if (payload.title.length > MAX_TITLE_LENGTH) {
    return `"title" must be ${MAX_TITLE_LENGTH} characters or fewer.`;
  }
  if (typeof payload.body !== 'string' || payload.body.trim().length === 0) {
    return '"body" is required.';
  }
  if (payload.body.length > MAX_BODY_LENGTH) {
    return `"body" must be ${MAX_BODY_LENGTH} characters or fewer.`;
  }
  if (payload.labels !== undefined) {
    if (!Array.isArray(payload.labels)) {
      return '"labels" must be an array of strings.';
    }
    if (payload.labels.length > MAX_LABELS) {
      return `"labels" must contain at most ${MAX_LABELS} entries.`;
    }
    for (const label of payload.labels) {
      if (typeof label !== 'string' || label.length > MAX_LABEL_LENGTH) {
        return 'Each label must be a string no longer than ' +
          `${MAX_LABEL_LENGTH} characters.`;
      }
    }
  }
  return null;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed.' }, 405, {
        Allow: 'POST, OPTIONS',
      });
    }

    if (!env.PROXY_API_KEY) {
      return jsonResponse(
        { error: 'Proxy is not configured (missing PROXY_API_KEY).' },
        500,
      );
    }
    const apiKey = request.headers.get('X-API-Key');
    if (apiKey !== env.PROXY_API_KEY) {
      return jsonResponse({ error: 'Invalid or missing X-API-Key.' }, 401);
    }

    if (!env.GITHUB_TOKEN) {
      return jsonResponse(
        { error: 'Proxy is not configured (missing GITHUB_TOKEN).' },
        500,
      );
    }

    let payload;
    try {
      payload = await request.json();
    } catch (_error) {
      return jsonResponse({ error: 'Request body must be valid JSON.' }, 400);
    }

    const validationError = validatePayload(payload);
    if (validationError) {
      return jsonResponse({ error: validationError }, 400);
    }

    const owner = env.GITHUB_OWNER || 'DevelopersCoffee';
    const repo = env.GITHUB_REPO || 'airo';

    let githubResponse;
    try {
      githubResponse = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/issues`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.GITHUB_TOKEN}`,
            Accept: 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'Content-Type': 'application/json',
            'User-Agent': 'airo-bug-report-proxy',
          },
          body: JSON.stringify({
            title: payload.title,
            body: payload.body,
            labels: payload.labels || [],
          }),
        },
      );
    } catch (_error) {
      return jsonResponse({ error: 'Failed to reach GitHub.' }, 502);
    }

    const githubData = await githubResponse.json().catch(() => null);

    if (!githubResponse.ok || githubData === null) {
      return jsonResponse(
        {
          error: 'GitHub rejected the issue.',
          githubStatus: githubResponse.status,
          githubMessage: githubData && githubData.message,
        },
        githubResponse.status >= 400 && githubResponse.status < 500
          ? githubResponse.status
          : 502,
      );
    }

    // Pass through only the fields the app's GitHubIssueResponse.fromJson
    // reads -- never forward the rest of GitHub's response verbatim.
    return jsonResponse(
      {
        number: githubData.number,
        html_url: githubData.html_url,
        title: githubData.title,
      },
      201,
    );
  },
};
