import { describe, expect, it } from 'vitest';
import {
	SurveyParseError,
	computeCompletion,
	getQuestion,
	isAnswered,
	isSectionComplete,
	isVisible,
	lintSurvey,
	parseSurvey,
	sectionCompletion,
	validateAnswer,
	type MultipleQuestion,
	type ScaleQuestion,
	type Section,
	type SingleQuestion,
	type SurveyDef,
	type TextListQuestion,
	type TextQuestion
} from './definition';

describe('parseSurvey', () => {
	it('throws when there is no top-level sections array', () => {
		expect(() => parseSurvey({})).toThrow(SurveyParseError);
	});

	it('parses meta and coerces question types, falling back gracefully on unknown ones', () => {
		const def = parseSurvey({
			survey: { id: 'x', editionId: 'ed1', year: 2026, title: 'T', version: 1 },
			sections: [
				{
					id: 's1',
					title: 'Section 1',
					questions: [
						{ id: 'q1', type: 'single', prompt: 'Pick one', options: [{ id: 'a', label: 'A' }] },
						{ id: 'q2', type: 'from_the_future', prompt: 'A type nobody has written yet' }
					]
				}
			]
		});
		expect(def.meta).toMatchObject({ id: 'x', editionId: 'ed1', year: 2026, version: 1 });
		expect(def.sections[0].questions[0].type).toBe('single');
		expect(def.sections[0].questions[1].type).toBe('from_the_future');
	});

	it('never throws on malformed question-level data', () => {
		expect(() => parseSurvey({ sections: [{ questions: [{ type: 'single' }] }] })).not.toThrow();
	});
});

describe('isVisible / showIf', () => {
	const target: SingleQuestion = {
		id: 'target',
		type: 'single',
		prompt: '',
		options: [
			{ id: 'a', label: 'A' },
			{ id: 'b', label: 'B' }
		]
	};
	const eqQuestion: SingleQuestion = {
		...target,
		id: 'dependent_eq',
		showIf: { questionId: 'target', op: 'eq', values: ['a'] }
	};
	const anyQuestion: MultipleQuestion = {
		id: 'dependent_any',
		type: 'multiple',
		prompt: '',
		options: [{ id: 'a', label: 'A' }],
		showIf: { questionId: 'target', op: 'includesAny', values: ['a', 'b'] }
	};

	it('is visible when there is no showIf', () => {
		expect(isVisible(target, {})).toBe(true);
	});

	it('hides when the target answer is missing', () => {
		expect(isVisible(eqQuestion, {})).toBe(false);
	});

	it('eq matches only an exact single-valued answer', () => {
		expect(isVisible(eqQuestion, { target: { kind: 'single', optionId: 'a' } })).toBe(true);
		expect(isVisible(eqQuestion, { target: { kind: 'single', optionId: 'b' } })).toBe(false);
	});

	it('includesAny matches when any selected id is in the list', () => {
		expect(isVisible(anyQuestion, { target: { kind: 'multiple', optionIds: ['b', 'z'] } })).toBe(
			true
		);
		expect(isVisible(anyQuestion, { target: { kind: 'multiple', optionIds: ['z'] } })).toBe(false);
	});
});

describe('isAnswered', () => {
	const q: TextQuestion = { id: 'q', type: 'text', prompt: '' };

	it('is false for missing or empty values', () => {
		expect(isAnswered(q, undefined)).toBe(false);
		expect(isAnswered(q, { kind: 'empty' })).toBe(false);
	});

	it('treats whitespace-only text as unanswered', () => {
		expect(isAnswered(q, { kind: 'text', text: '   ' })).toBe(false);
	});

	it('is true for real text', () => {
		expect(isAnswered(q, { kind: 'text', text: 'hi' })).toBe(true);
	});
});

describe('validateAnswer', () => {
	it('requires an answer only when the question is required', () => {
		const required: TextQuestion = { id: 'q', type: 'text', prompt: '', required: true };
		const optional: TextQuestion = { id: 'q', type: 'text', prompt: '' };
		expect(validateAnswer(required, undefined)).toMatch(/required/i);
		expect(validateAnswer(required, { kind: 'text', text: 'ok' })).toBeNull();
		expect(validateAnswer(optional, undefined)).toBeNull();
	});

	describe('single', () => {
		const q: SingleQuestion = {
			id: 'q',
			type: 'single',
			prompt: '',
			options: [{ id: 'a', label: 'A' }],
			allowOther: true
		};

		it('rejects an option that is not listed', () => {
			expect(validateAnswer(q, { kind: 'single', optionId: 'nope' })).not.toBeNull();
		});

		it('accepts a listed option', () => {
			expect(validateAnswer(q, { kind: 'single', optionId: 'a' })).toBeNull();
		});

		it('requires write-in text when "other" is selected', () => {
			expect(validateAnswer(q, { kind: 'single', optionId: 'other' })).not.toBeNull();
			expect(validateAnswer(q, { kind: 'single', optionId: 'other', other: 'custom' })).toBeNull();
		});
	});

	describe('multiple', () => {
		const q: MultipleQuestion = {
			id: 'q',
			type: 'multiple',
			prompt: '',
			options: [
				{ id: 'a', label: 'A' },
				{ id: 'b', label: 'B' },
				{ id: 'c', label: 'C' },
				{ id: 'none', label: 'None' }
			],
			limit: 2,
			exclusiveOptions: ['none']
		};

		it('rejects an option that is not listed', () => {
			expect(validateAnswer(q, { kind: 'multiple', optionIds: ['nope'] })).not.toBeNull();
		});

		it('enforces the limit', () => {
			expect(validateAnswer(q, { kind: 'multiple', optionIds: ['a', 'b', 'c'] })).toMatch(
				/at most 2/i
			);
		});

		it('allows selections up to the limit', () => {
			expect(validateAnswer(q, { kind: 'multiple', optionIds: ['a', 'b'] })).toBeNull();
		});

		it('rejects combining an exclusive option with others', () => {
			expect(validateAnswer(q, { kind: 'multiple', optionIds: ['none', 'a'] })).not.toBeNull();
		});

		it('allows the exclusive option on its own', () => {
			expect(validateAnswer(q, { kind: 'multiple', optionIds: ['none'] })).toBeNull();
		});
	});

	describe('scale / nps', () => {
		const scale: ScaleQuestion = { id: 'q', type: 'scale', prompt: '', min: 1, max: 5 };

		it('rejects out-of-range values', () => {
			expect(validateAnswer(scale, { kind: 'number', value: 0 })).not.toBeNull();
			expect(validateAnswer(scale, { kind: 'number', value: 6 })).not.toBeNull();
		});

		it('accepts values inside the range', () => {
			expect(validateAnswer(scale, { kind: 'number', value: 3 })).toBeNull();
		});
	});

	describe('text', () => {
		const q: TextQuestion = { id: 'q', type: 'text', prompt: '', maxLength: 5 };

		it('rejects text over maxLength', () => {
			expect(validateAnswer(q, { kind: 'text', text: 'too long' })).not.toBeNull();
		});

		it('accepts text within maxLength', () => {
			expect(validateAnswer(q, { kind: 'text', text: 'ok' })).toBeNull();
		});
	});

	describe('text_list', () => {
		const q: TextListQuestion = { id: 'q', type: 'text_list', prompt: '', limit: 2 };

		it('rejects more non-blank items than the limit', () => {
			expect(validateAnswer(q, { kind: 'list', items: ['a', 'b', 'c'] })).not.toBeNull();
		});

		it('does not count blank items toward the limit', () => {
			expect(validateAnswer(q, { kind: 'list', items: ['a', '', 'b'] })).toBeNull();
		});
	});

	it('never enforces anything for an unknown question type', () => {
		const q = { id: 'q', type: 'from_the_future', prompt: '' };
		expect(validateAnswer(q, { kind: 'text', text: 'anything' })).toBeNull();
	});
});

describe('completion helpers', () => {
	const section: Section = {
		id: 's',
		title: 'S',
		questions: [
			{ id: 'req', type: 'single', prompt: '', required: true, options: [{ id: 'a', label: 'A' }] },
			{ id: 'opt', type: 'text', prompt: '' }
		]
	};
	const def: SurveyDef = {
		meta: { id: 'x', editionId: 'e', year: 2026, title: 'T', version: 1 },
		sections: [section]
	};

	it('computeCompletion counts every visible, known, answered question', () => {
		expect(computeCompletion(def, {})).toBe(0);
		expect(computeCompletion(def, { req: { kind: 'single', optionId: 'a' } })).toBe(50);
		expect(
			computeCompletion(def, {
				req: { kind: 'single', optionId: 'a' },
				opt: { kind: 'text', text: 'hi' }
			})
		).toBe(100);
	});

	it('isSectionComplete only cares about required questions', () => {
		expect(isSectionComplete(section, {})).toBe(false);
		expect(isSectionComplete(section, { req: { kind: 'single', optionId: 'a' } })).toBe(true);
	});

	it('sectionCompletion counts required and optional questions alike', () => {
		expect(sectionCompletion(section, { req: { kind: 'single', optionId: 'a' } })).toBe(50);
	});

	it('a section with no visible questions is 100% complete', () => {
		const empty: Section = { id: 'e', title: 'E', questions: [] };
		expect(sectionCompletion(empty, {})).toBe(100);
		expect(isSectionComplete(empty, {})).toBe(true);
	});

	it('getQuestion finds by id across sections, or returns undefined', () => {
		expect(getQuestion(def, 'req')?.id).toBe('req');
		expect(getQuestion(def, 'missing')).toBeUndefined();
	});
});

describe('lintSurvey', () => {
	function baseDef(sections: Section[]): SurveyDef {
		return { meta: { id: 'x', editionId: 'e', year: 2026, title: 'T', version: 1 }, sections };
	}

	it('passes for a minimal valid survey', () => {
		const def = baseDef([
			{
				id: 's',
				title: 'S',
				questions: [{ id: 'q', type: 'single', prompt: 'p', options: [{ id: 'a', label: 'A' }] }]
			}
		]);
		expect(lintSurvey(def).filter((i) => i.level === 'error')).toHaveLength(0);
	});

	it('flags duplicate question ids', () => {
		const def = baseDef([
			{
				id: 's',
				title: 'S',
				questions: [
					{ id: 'q', type: 'text', prompt: 'p' },
					{ id: 'q', type: 'text', prompt: 'p2' }
				]
			}
		]);
		expect(
			lintSurvey(def).some((i) => i.level === 'error' && /duplicate question id/i.test(i.message))
		).toBe(true);
	});

	it('flags unknown question types', () => {
		const def = baseDef([
			{ id: 's', title: 'S', questions: [{ id: 'q', type: 'mystery', prompt: 'p' }] }
		]);
		expect(lintSurvey(def).some((i) => /unknown type/i.test(i.message))).toBe(true);
	});

	it('flags a showIf referencing a non-existent question', () => {
		const def = baseDef([
			{
				id: 's',
				title: 'S',
				questions: [
					{
						id: 'q',
						type: 'text',
						prompt: 'p',
						showIf: { questionId: 'ghost', op: 'eq', values: ['x'] }
					}
				]
			}
		]);
		expect(lintSurvey(def).some((i) => /showIf references unknown question/i.test(i.message))).toBe(
			true
		);
	});

	it('flags exclusiveOptions referencing an unknown option', () => {
		const def = baseDef([
			{
				id: 's',
				title: 'S',
				questions: [
					{
						id: 'q',
						type: 'multiple',
						prompt: 'p',
						options: [{ id: 'a', label: 'A' }],
						exclusiveOptions: ['ghost']
					}
				]
			}
		]);
		expect(
			lintSurvey(def).some((i) => /exclusiveOptions references unknown option/i.test(i.message))
		).toBe(true);
	});

	it('flags an invalid scale min/max', () => {
		const def = baseDef([
			{ id: 's', title: 'S', questions: [{ id: 'q', type: 'scale', prompt: 'p', min: 5, max: 1 }] }
		]);
		expect(lintSurvey(def).some((i) => /invalid min\/max/i.test(i.message))).toBe(true);
	});
});
