import { describe, expect, it } from 'vitest';
import { authorizeRequest, issueSession } from '../src/lib/security';
const origin = 'http://127.0.0.1:3000';
const request = (headers: Record<string,string> = {}, method = 'POST') => new Request(origin + '/api/workspace', { method, headers: { host: '127.0.0.1:3000', origin, ...headers } });
describe('local browser boundary', () => {
  it('requires a valid server-issued session on data routes', () => { expect(() => authorizeRequest(request())).toThrow(/session/i); expect(() => authorizeRequest(request({ cookie: `worldos_session=${issueSession()}` }))).not.toThrow(); });
  it('rejects cross-site mutations even with a session', () => { expect(() => authorizeRequest(request({ origin: 'https://evil.example', cookie: `worldos_session=${issueSession()}` }))).toThrow(/origin/i); });
  it('rejects untrusted host and cross-site session bootstrapping', () => { expect(() => authorizeRequest(request({ host: 'evil.example' }), true)).toThrow(/host/i); expect(() => authorizeRequest(request({ 'sec-fetch-site': 'cross-site' }, 'GET'), true)).toThrow(/cross-site/i); });
  it('requires Origin on writes and rejects tampered cookies', () => { const r = request({ cookie: `worldos_session=${issueSession()}` }); r.headers.delete('origin'); expect(() => authorizeRequest(r)).toThrow(/origin/i); expect(() => authorizeRequest(request({ cookie: 'worldos_session=bad' }))).toThrow(/session/i); });
});
