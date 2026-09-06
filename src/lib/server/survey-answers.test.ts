import { describe, expect, it } from 'vitest';
import { answerToRows, coerceAnswerValue, rowsToAnswers } from './survey-answers';
import type { Question, SurveyDef } from '$lib/surveys/definition';

// These three functions are the untrusted-input boundary between the client and the DB:
// coerceAnswerValue turns arbitrary client JSON into a typed AnswerValue (or rejects it),
// answerToRows/rowsToAnswers convert between that and the normalized answers table rows.
// Deliberately not covered here: saveAnswers/submitResponse/getOrCreateResponse — those
// need a real database and are integration-tested by exercising the app itself.

describe('coerceAnswerValue', () => {
	const single: Question = {
		id: 'q',
		type: 'single',
		prompt: '',
		options: [{ id: 'a', label: 'A' }]
	};

	it('coerces a well-shaped payload for the question type', () => {
		expect(coerceAnswerValue(single, { kind: 'single', optionId: 'a' })).toEqual({
			kind: 'single',
			optionId: 'a',
			other: undefined
		});
	});

	it('rejects a payload whose kind does not match the question type', () => {
		expect(coerceAnswerValue(single, { kind: 'text', text: 'x' })).toBeNull();
	});

	it('treats non-object input as empty rather than crashing', () => {
		expect(coerceAnswerValue(single, 'not an object')).toEqual({ kind: 'empty' });
		expect(coerceAnswerValue(single, null)).toEqual({ kind: 'empty' });
	});

	it('dedupes selected option ids for multiple-choice answers', () => {
		const multi: Question = { id: 'q', type: 'multiple', prompt: '', options: [] };
		expect(coerceAnswerValue(multi, { kind: 'multiple', optionIds: ['a', 'a', 'b'] })).toEqual({
			kind: 'multiple',
			optionIds: ['a', 'b'],
			other: undefined
		});
	});

	it('never crashes on an unknown question type', () => {
		const unknown: Question = { id: 'q', type: 'from_the_future', prompt: '' };
		expect(coerceAnswerValue(unknown, { anything: true })).toEqual({ kind: 'empty' });
	});
});

describe('answerToRows', () => {
	it('drops a single answer with no option selected', () => {
		const q: Question = { id: 'q', type: 'single', prompt: '', options: [] };
		expect(answerToRows(q, { kind: 'single', optionId: '' })).toEqual([]);
	});

	it('writes one row per selected option, tagging write-in text only on the "other" row', () => {
		const q: Question = { id: 'q', type: 'multiple', prompt: '', options: [] };
		const rows = answerToRows(q, { kind: 'multiple', optionIds: ['a', 'other'], other: 'custom' });
		expect(rows).toEqual([
			{ questionId: 'q', optionId: 'a', textValue: null },
			{ questionId: 'q', optionId: 'other', textValue: 'custom' }
		]);
	});

	it('writes positioned rows for a text list, dropping blank entries', () => {
		const q: Question = { id: 'q', type: 'text_list', prompt: '' };
		const rows = answerToRows(q, { kind: 'list', items: ['a', '', ' b '] });
		expect(rows).toEqual([
			{ questionId: 'q', textValue: 'a', position: 0 },
			{ questionId: 'q', textValue: 'b', position: 1 }
		]);
	});

	it('never stores anything for an unknown question type', () => {
		const q: Question = { id: 'q', type: 'from_the_future', prompt: '' };
		expect(answerToRows(q, { kind: 'text', text: 'x' })).toEqual([]);
	});
});

describe('rowsToAnswers', () => {
	const def: SurveyDef = {
		meta: { id: 'x', editionId: 'e', year: 2026, title: 'T', version: 1 },
		sections: [
			{
				id: 's',
				title: 'S',
				questions: [
					{ id: 'single_q', type: 'single', prompt: '', options: [{ id: 'a', label: 'A' }] },
					{ id: 'list_q', type: 'text_list', prompt: '' },
					{ id: 'unknown_q', type: 'from_the_future', prompt: '' }
				]
			}
		]
	};

	function row(overrides: {
		questionId: string;
		optionId?: string | null;
		numberValue?: number | null;
		textValue?: string | null;
		position?: number | null;
	}) {
		return {
			id: 'r',
			responseId: 'resp',
			optionId: null,
			numberValue: null,
			textValue: null,
			position: null,
			...overrides
		};
	}

	it('rebuilds a single answer from its row', () => {
		const answers = rowsToAnswers(def, [row({ questionId: 'single_q', optionId: 'a' })]);
		expect(answers.single_q).toEqual({ kind: 'single', optionId: 'a', other: undefined });
	});

	it('orders text_list items by position, not row order', () => {
		const rows = [
			row({ questionId: 'list_q', textValue: 'second', position: 1 }),
			row({ questionId: 'list_q', textValue: 'first', position: 0 })
		];
		expect(rowsToAnswers(def, rows).list_q).toEqual({ kind: 'list', items: ['first', 'second'] });
	});

	it('skips rows for unknown-type questions', () => {
		const rows = [row({ questionId: 'unknown_q', numberValue: 1 })];
		expect(rowsToAnswers(def, rows).unknown_q).toBeUndefined();
	});

	it('skips rows for questions no longer in the definition', () => {
		const rows = [row({ questionId: 'ghost_q', optionId: 'a' })];
		expect(rowsToAnswers(def, rows)).toEqual({});
	});
});
