import type { Set, Game } from '$lib/startql/result_types';

export type StageStat = {
	name: string;
	gamesPlayed: number;
	gamesWon: number;
	gamesLost: number;
	winRate: number;
};

export type StageStatsResult = {
	stages: StageStat[];
	totalGames: number;
};

/**
 * Compute stage frequency and win rates from a player's set history.
 */
export function computeStageStats(sets: Set[], playerEntrantId: number): StageStatsResult {
	const stageMap = new Map<string, { played: number; won: number }>();
	let totalGames = 0;

	for (const set of sets) {
		for (const game of set.games) {
			if (!game.stage) continue;

			totalGames++;
			const stageName = game.stage.name;
			const record = stageMap.get(stageName) ?? { played: 0, won: 0 };
			record.played++;

			if (game.winnerId === playerEntrantId) record.won++;

			stageMap.set(stageName, record);
		}
	}

	const stages: StageStat[] = [];
	for (const [name, record] of stageMap) {
		stages.push({
			name,
			gamesPlayed: record.played,
			gamesWon: record.won,
			gamesLost: record.played - record.won,
			winRate: record.played > 0 ? Math.round((record.won / record.played) * 10000) / 100 : 0
		});
	}

	stages.sort((a, b) => b.gamesPlayed - a.gamesPlayed);

	return { stages, totalGames };
}
