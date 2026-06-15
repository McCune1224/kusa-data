import type { Set, SetSlot } from '$lib/startql/result_types';

export type EloResult = {
	current: number;
	history: { elo: number; setCount: number }[];
	gamesPlayed: number;
};

const INITIAL_ELO = 1500;
const K_FACTOR = 32;

/**
 * Expected score for player with rating A against player with rating B.
 */
function expectedScore(ratingA: number, ratingB: number): number {
	return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

/**
 * Determine the opponent's entrant ID from slots.
 */
function getOpponentEntrantId(slots: SetSlot[], playerEntrantId: number): number | null {
	for (const slot of slots) {
		if (slot.entrant && slot.entrant.id !== playerEntrantId) {
			return slot.entrant.id;
		}
	}
	return null;
}

/**
 * Compute Elo rating from a player's set history.
 * Processes sets in chronological order (oldest first).
 *
 * Note: This uses the player's own entrant IDs from each set.
 * Since entrant IDs change per tournament, we track by the entrant ID
 * found in each individual set rather than a single global ID.
 */
export function computeElo(
	sets: Set[],
	getPlayerEntrantId: (set: Set) => number | null
): EloResult {
	let elo = INITIAL_ELO;
	const history: { elo: number; setCount: number }[] = [];
	let gamesPlayed = 0;

	// Process oldest sets first for proper Elo progression
	const chronological = [...sets]
		.filter((s) => s.state === 3 && s.completedAt)
		.sort((a, b) => new Date(a.completedAt!).getTime() - new Date(b.completedAt!).getTime());

	for (const set of chronological) {
		const playerEntrantId = getPlayerEntrantId(set);
		if (!playerEntrantId) continue;

		const opponentId = getOpponentEntrantId(set.slots, playerEntrantId);
		if (!opponentId) continue; // bye

		// Find the player and opponent scores
		const playerSlot = set.slots.find((s) => s.entrant?.id === playerEntrantId);
		const opponentSlot = set.slots.find((s) => s.entrant?.id === opponentId);

		const playerScore = playerSlot?.standing?.stats?.score?.value;
		const opponentScore = opponentSlot?.standing?.stats?.score?.value;

		if (playerScore == null || opponentScore == null) continue;

		// Determine actual score (1 = win, 0 = loss, 0.5 = draw)
		let actualScore: number;
		if (playerScore > opponentScore) {
			actualScore = 1;
		} else if (opponentScore > playerScore) {
			actualScore = 0;
		} else {
			actualScore = 0.5;
		}

		// We don't know the opponent's Elo, so approximate using current Elo
		// (assumes opponent has similar rating - this is a simplification)
		const expected = expectedScore(elo, elo);
		elo = Math.round(elo + K_FACTOR * (actualScore - expected));
		gamesPlayed++;

		// Record checkpoint every 10 sets
		if (gamesPlayed % 10 === 0) {
			history.push({ elo, setCount: gamesPlayed });
		}
	}

	// Always add final state
	history.push({ elo, setCount: gamesPlayed });

	return { current: elo, history, gamesPlayed };
}
