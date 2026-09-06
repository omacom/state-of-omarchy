import { describe, expect, it } from 'vitest';
import { getSafeNext } from './utils';

describe('getSafeNext', () => {
	it('falls back to the default when null', () => {
		expect(getSafeNext(null)).toBe('/survey');
	});

	it('honors a custom fallback', () => {
		expect(getSafeNext(null, '/')).toBe('/');
	});

	it('accepts a same-origin path', () => {
		expect(getSafeNext('/survey/done')).toBe('/survey/done');
	});

	it('rejects a protocol-relative URL (open-redirect vector)', () => {
		expect(getSafeNext('//evil.com')).toBe('/survey');
	});

	it('rejects an absolute URL', () => {
		expect(getSafeNext('https://evil.com')).toBe('/survey');
	});

	it('rejects a value with no leading slash', () => {
		expect(getSafeNext('evil.com')).toBe('/survey');
	});
});
