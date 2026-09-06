import { describe, expect, it } from 'vitest';
import { lintSurvey } from './definition';
import { CURRENT_EDITION, listEditions, loadSurvey, UnknownEditionError } from './loader';

// Complements `pnpm survey:lint`: this runs the same lint automatically whenever the
// test suite runs, so a broken survey.yml fails CI instead of relying on someone
// remembering to run the script by hand.

describe('loadSurvey', () => {
	it('lists the current edition', () => {
		expect(listEditions()).toContain(CURRENT_EDITION);
	});

	it('parses the current edition into a lint-clean SurveyDef', () => {
		const def = loadSurvey(CURRENT_EDITION);
		expect(def.sections.length).toBeGreaterThan(0);
		expect(lintSurvey(def).filter((issue) => issue.level === 'error')).toEqual([]);
	});

	it('throws a typed error for an unknown edition', () => {
		expect(() => loadSurvey('not-a-real-edition')).toThrow(UnknownEditionError);
	});
});
