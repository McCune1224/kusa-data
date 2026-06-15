import type { Set, SetSlot } from '$lib/startql/result_types';

export type WinLossRecord = {
	wins: number;
	losses: number;
	byes: number;
	total: number;
	winRate: number; // 0-100
};

export type Streak = {
	type: 'win' | 'loss' | null;
	count: number;
};

/**
 * Determine if the player won a set given their entrant ID and the set slots.
 * The player's entrant ID appears in one of the slots. If that slot has a higher
 * score.value (from standing.stats.score), they won. Falls back to displayScore
 * parsing if stats are missing.
 */
export function didPlayerWin(playerEntrantId: number, slots: SetSlot[]): boolean | null {
	const playerSlot = slots.find((s) => s.entrant?.id === playerEntrantId);
	const opponentSlot = slots.find((s) => s.entrant?.id !== playerEntrantId);

	if (!playerSlot || !opponentSlot) return null; // bye or incomplete

	const playerScore = playerSlot.standing?.stats?.score?.value;
	const opponentScore = opponentSlot.standing?.stats?.score?.value;

	if (playerScore != null && opponentScore != null) {
		if (playerScore > opponentScore) return true;
		if (opponentScore > playerScore) return false;
		return null; // draw / unknown
	}

	return null;
}

/**
 * Compute W/L record from an array of completed sets.
 */
export function computeWinLoss(sets: Set[], playerEntrantId: number): WinLossRecord {
	let wins = 0;
	let losses = 0;
	let byes = 0;

	for (const set of sets) {
		if (set.state !== 3) continue; // only completed sets

		// Bye detection: only 1 slot or opponent slot has no entrant
		const hasOpponent = set.slots.some(
			(s) => s.entrant?.id !== playerEntrantId && s.entrant !== null
		);
		if (!hasOpponent) {
			byes++;
			continue;
		}

		const won = didPlayerWin(playerEntrantId, set.slots);
		if (won === true) wins++;
		else if (won === false) losses++;
	}

	const total = wins + losses;
	return {
		wins,
		losses,
		byes,
		total,
		winRate: total > 0 ? Math.round((wins / total) * 10000) / 100 : 0
	};
}

/**
 * Compute current win/loss streak from sets sorted newest-first.
 */
export function computeStreak(sets: Set[], playerEntrantId: number): Streak {
	const completed = sets.filter((s) => s.state === 3);

	for (const set of completed) {
		const hasOpponent = set.slots.some(
			(s) => s.entrant?.id !== playerEntrantId && s.entrant !== null
		);
		if (!hasOpponent) continue;

		const won = didPlayerWin(playerEntrantId, set.slots);
		if (won !== null) {
			const type = won ? 'win' : 'loss';
			let count = 1;
			for (let i = 1; i < completed.length; i++) {
				const s = completed[i];
				const opp = s.slots.some(
					(slot) => slot.entrant?.id !== playerEntrantId && slot.entrant !== null
				);
				if (!opp) continue;
				const result = didPlayerWin(playerEntrantId, s.slots);
				if (result === null) break;
				if ((won && result) || (!won && !result)) {
					count++;
				} else {
					break;
				}
			}
			return { type, count };
		}
	}

	return { type: null, count: 0 };
}

/**
 * Find the best (longest) win streak from all sets.
 */
export function computeBestWinStreak(sets: Set[], playerEntrantId: number): number {
	const completed = sets.filter((s) => s.state === 3);
	const results: boolean[] = [];

	for (const set of completed) {
		const hasOpponent = set.slots.some(
			(s) => s.entrant?.id !== playerEntrantId && s.entrant !== null
		);
		if (!hasOpponent) continue;
		const won = didPlayerWin(playerEntrantId, set.slots);
		if (won !== null) results.push(won);
	}

	let best = 0;
	let current = 0;
	for (const r of results) {
		if (r) {
			current++;
			best = Math.max(best, current);
		} else {
			current = 0;
		}
	}
	return best;
}
