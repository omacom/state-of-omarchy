import { describe, expect, it } from 'vitest';
import { isValidEmail } from './waitlist';

// joinWaitlist itself needs a real database and is intentionally not covered here.

describe('isValidEmail', () => {
	it.each(['a@b.com', 'first.last@sub.example.co', 'a@b.io'])('accepts %s', (email) => {
		expect(isValidEmail(email)).toBe(true);
	});

	it.each(['', 'not-an-email', 'a@b', '@b.com', 'a@.com', 'a b@c.com'])('rejects %s', (email) => {
		expect(isValidEmail(email)).toBe(false);
	});
});
