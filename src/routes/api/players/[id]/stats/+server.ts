import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getPlayerSets } from '$lib/startql/player';
import {
	computeWinLoss,
	computeStreak,
	computeBestWinStreak,
	computeCharacterStats,
	computeStageStats,
	computeElo
} from '$lib/stats';

export const GET: RequestHandler = async (event) => {
	const playerId = +event.params.id;

	if (isNaN(playerId)) {
		return json({ error: 'Invalid player ID' }, { status: 400 });
	}

	try {
		// Fetch all sets (paginated through all pages)
		const firstPage = await getPlayerSets(playerId, 1, 50);
		const allSets = [...firstPage.player.sets.nodes];
		const totalPages = firstPage.player.sets.pageInfo.totalPages;

		if (totalPages > 1) {
			const remainingPages = Array.from({ length: totalPages - 1 }, (_, i) => i + 2);
			const pageResults = await Promise.all(
				remainingPages.map((page) => getPlayerSets(playerId, page, 50))
			);
			for (const page of pageResults) {
				allSets.push(...page.player.sets.nodes);
			}
		}

		// We need the player's entrant ID from the sets to compute stats.
		// The entrant ID is in each set's slot for the player.
		// We extract it from the first available set.
		const playerEntrantId = getPlayerEntrantId(allSets);

		if (!playerEntrantId) {
			return json({
				winLoss: { wins: 0, losses: 0, byes: 0, total: 0, winRate: 0 },
				streak: { type: null, count: 0 },
				bestWinStreak: 0,
				characters: { characters: [], totalGames: 0 },
				stages: { stages: [], totalGames: 0 },
				setCount: 0
			});
		}

		const completedSets = allSets.filter((s) => s.state === 3);
		const winLoss = computeWinLoss(completedSets, playerEntrantId);
		const streak = computeStreak(completedSets, playerEntrantId);
		const bestWinStreak = computeBestWinStreak(completedSets, playerEntrantId);
		const characters = computeCharacterStats(completedSets, playerEntrantId);
		const stages = computeStageStats(completedSets, playerEntrantId);
		const elo = computeElo(completedSets, (set) => {
			for (const slot of set.slots) {
				if (slot.entrant?.id) return slot.entrant.id;
			}
			return null;
		});

		return json({
			winLoss,
			streak,
			bestWinStreak,
			characters,
			stages,
			elo,
			setCount: completedSets.length
		});
	} catch (e) {
		console.error('Failed to compute player stats:', e);
		return json({ error: 'Failed to compute stats' }, { status: 500 });
	}
};

/**
 * Extract the player's entrant ID from set slots.
 * Assumes the player appears in at least one completed set.
 */
function getPlayerEntrantId(
	sets: { slots: { entrant: { id: number } | null }[] }[]
): number | null {
	for (const set of sets) {
		for (const slot of set.slots) {
			if (slot.entrant) return slot.entrant.id;
		}
	}
	return null;
}
