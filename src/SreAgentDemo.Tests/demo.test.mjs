import test from 'node:test';
import assert from 'node:assert/strict';
import { buildPrompts, describeRun, isValidRun, runTraffic } from '../SreAgentDemo.Api/wwwroot/demo.mjs';

function response(status) {
  return { status, text: async () => '{}' };
}

test('traffic is bounded to 60 requests, 20 per endpoint, with at most six in flight', async () => {
  let active = 0;
  let maximum = 0;
  const calls = [];
  const progress = [];
  const run = await runTraffic({
    fetchImpl: async (url, options) => {
      active++;
      maximum = Math.max(maximum, active);
      calls.push({ url, options });
      await new Promise(resolve => setTimeout(resolve, 1));
      active--;
      return response(calls.length % 5 === 0 ? 500 : 200);
    },
    onProgress: count => progress.push(count)
  });
  assert.equal(run.results.length, 60);
  assert.equal(maximum, 6);
  assert.equal(progress.at(-1), 60);
  for (const endpoint of ['/products', '/orders', '/checkout']) {
    const requests = calls.filter(call => call.url.startsWith(`${endpoint}?demoRun=${run.runId}`));
    assert.equal(requests.length, 20);
    for (const request of requests) {
      assert.equal(request.options.cache, 'no-store');
      assert.equal(request.options.headers?.['X-Admin-Token'], undefined);
      if (endpoint !== '/products') {
        assert.equal(request.options.method, 'POST');
        assert.deepEqual(JSON.parse(request.options.body), { productId: 1, quantity: 1 });
      }
    }
  }
  assert.ok(isValidRun(run));
  assert.ok(!isValidRun(run, true));
});

test('recovery requires exactly 60 HTTP 200 responses and 20 per endpoint', async () => {
  const run = await runTraffic({ fetchImpl: async () => response(200) });
  assert.ok(isValidRun(run, true));
  assert.ok(!isValidRun(run));
  assert.ok(!isValidRun({ ...run, results: run.results.slice(1) }, true));
  assert.ok(!isValidRun({ ...run, results: run.results.map(row => ({ ...row, endpoint: '/products' })) }, true));
  for (const status of [0, 401, 403, 429, 500, 503]) {
    assert.ok(!isValidRun({ ...run, results: [{ ...run.results[0], status }, ...run.results.slice(1)] }, true));
  }
});

test('network failures are explicit, not converted into successful requests', async () => {
  const run = await runTraffic({ fetchImpl: async () => { throw new Error('network unavailable'); } });
  assert.ok(!isValidRun(run));
  assert.ok(!isValidRun(run, true));
  assert.equal(run.results.filter(row => row.status === 0).length, 60);
  assert.match(describeRun(run), /Otros errores: 60/);
  assert.match(describeRun(run), /network unavailable/);
});

test('abort stops dispatching traffic and does not qualify as a complete sample', async () => {
  const controller = new AbortController();
  let calls = 0;
  const run = await runTraffic({
    signal: controller.signal,
    fetchImpl: async () => {
      calls++;
      controller.abort();
      return response(200);
    }
  });
  assert.equal(calls, 1);
  assert.ok(!isValidRun(run, true));
});

test('prompts use the actual UTC windows and isolate runs, without assuming recovery', async () => {
  const incident = await runTraffic({ fetchImpl: async () => response(500) });
  const recovery = await runTraffic({ fetchImpl: async () => response(200) });
  incident.startUtc = '2026-11-12T15:00:00.000Z';
  incident.endUtc = '2026-11-12T15:01:00.000Z';
  recovery.startUtc = '2026-11-12T15:10:00.000Z';
  recovery.endUtc = '2026-11-12T15:11:00.000Z';
  assert.deepEqual(buildPrompts(null, null), { investigate: '', cause: '', recovery: '', report: '' });
  assert.equal(buildPrompts(incident, null).recovery, '');
  assert.equal(buildPrompts(incident, null).report, '');
  const prompts = buildPrompts(incident, recovery);
  assert.match(prompts.investigate, /2026-11-12T14:59:50.000Z a 2026-11-12T15:01:10.000Z/);
  assert.ok(prompts.investigate.includes(`demoRun=${incident.runId}`));
  assert.ok(prompts.recovery.includes(`demoRun=${recovery.runId}`));
  assert.ok(prompts.recovery.includes(`demoRun=${incident.runId}`));
  for (const prompt of Object.values(prompts)) {
    assert.match(prompt, /2e737e8a-b75f-49e1-86e4-e3f8a67ca2eb/);
    assert.match(prompt, /No listes app settings/);
    assert.match(prompt, /Solo lectura/);
  }
  assert.match(prompts.report, /ni calcules MTTR sin justificar inicio y fin/i);
});

test('malformed stored samples cannot produce valid prompts', () => {
  for (const value of [null, {}, { results: [] }, { results: Array(60).fill(null) }]) {
    assert.ok(!isValidRun(value));
    assert.equal(buildPrompts(value, value).report, '');
  }
});
