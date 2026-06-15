import type { PlayerTournamentRecord } from '$lib/startql/player';

export type PlacementStat = {
	averagePlacement: number;
	medianPlacement: number;
	bestPlacement: number | null;
	bestEventName: string | null;
	tournamentsPlayed: number;
	top8Count: number;
	top3Count: number;
	winCount: number; // tournament wins
};

/**
 * Compute placement statistics from a player's tournament history.
 * Placement is extracted from the first entrant node's standing.
 */
export function computePlacementStats(tournaments: PlayerTournamentRecord[]): PlacementStat {
	const placements: number[] = [];
	let bestPlacement: number | null = null;
	let bestEventName: string | null = null;
	let top8 = 0;
	let top3 = 0;
	let wins = 0;

	for (const t of tournaments) {
		for (const event of t.events) {
			const node = event.entrants.nodes[0];
			if (!node?.standing) continue;

			const p = node.standing.placement;
			placements.push(p);

			if (bestPlacement === null || p < bestPlacement) {
				bestPlacement = p;
				bestEventName = event.name;
			}

			if (p <= 8) top8++;
			if (p <= 3) top3++;
			if (p === 1) wins++;
		}
	}

	if (placements.length === 0) {
		return {
			averagePlacement: 0,
			medianPlacement: 0,
			bestPlacement: null,
			bestEventName: null,
			tournamentsPlayed: 0,
			top8Count: 0,
			top3Count: 0,
			winCount: 0
		};
	}

	const sorted = [...placements].sort((a, b) => a - b);
	const mid = Math.floor(sorted.length / 2);
	const median = sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];

	const average =
		Math.round((placements.reduce((sum, p) => sum + p, 0) / placements.length) * 100) / 100;

	return {
		averagePlacement: average,
		medianPlacement: median,
		bestPlacement,
		bestEventName,
		tournamentsPlayed: placements.length,
		top8Count: top8,
		top3Count: top3,
		winCount: wins
	};
}
