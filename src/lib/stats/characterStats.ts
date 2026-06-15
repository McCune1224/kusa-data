import type { Set, Game } from '$lib/startql/result_types';

export type CharacterStat = {
	name: string;
	gamesPlayed: number;
	gamesWon: number;
	gamesLost: number;
	winRate: number;
	usagePercent: number;
};

export type CharacterStatsResult = {
	characters: CharacterStat[];
	totalGames: number;
};

/**
 * Determine which character a player used in a game by matching their entrant ID
 * against the game's selections array.
 */
function getPlayerCharacter(game: Game, playerEntrantId: number): string | null {
	for (const sel of game.selections) {
		if (sel.entrant.id === playerEntrantId && sel.character) {
			return sel.character.name;
		}
	}
	return null;
}

/**
 * Determine if the player won a game given their entrant ID.
 * The winnerId in a game refers to the entrant ID that won.
 */
function didPlayerWinGame(game: Game, playerEntrantId: number): boolean | null {
	if (game.winnerId === null) return null;
	return game.winnerId === playerEntrantId;
}

/**
 * Compute character usage and win rates from a player's set history.
 */
export function computeCharacterStats(sets: Set[], playerEntrantId: number): CharacterStatsResult {
	const charMap = new Map<string, { played: number; won: number }>();
	let totalGames = 0;

	for (const set of sets) {
		for (const game of set.games) {
			const character = getPlayerCharacter(game, playerEntrantId);
			if (!character) continue;

			totalGames++;
			const record = charMap.get(character) ?? { played: 0, won: 0 };
			record.played++;

			const won = didPlayerWinGame(game, playerEntrantId);
			if (won === true) record.won++;

			charMap.set(character, record);
		}
	}

	const characters: CharacterStat[] = [];
	for (const [name, record] of charMap) {
		characters.push({
			name,
			gamesPlayed: record.played,
			gamesWon: record.won,
			gamesLost: record.played - record.won,
			winRate: record.played > 0 ? Math.round((record.won / record.played) * 10000) / 100 : 0,
			usagePercent: totalGames > 0 ? Math.round((record.played / totalGames) * 10000) / 100 : 0
		});
	}

	characters.sort((a, b) => b.gamesPlayed - a.gamesPlayed);

	return { characters, totalGames };
}
