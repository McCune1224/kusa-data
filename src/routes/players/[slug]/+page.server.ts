import { getPlayer, userTournamentHistory, type PlayerTournamentUser } from '$lib/startql/player';
import type { PageServerLoad } from './$types';
import redisClient, { jsonSet } from '$lib/redisClient';

export const load: PageServerLoad = async ({ params }) => {
	const id = +params.slug;

	if (isNaN(id)) {
		return { playerResponse: { user: null }, slug: params.slug, tournamentHistory: null };
	}

	const playerResponse = await getPlayer(+params.slug);
	if (playerResponse.user === null) {
		return { playerResponse: { user: null }, slug: params.slug, tournamentHistory: null };
	}

	const cacheTournamentHistory = await redisClient.get(`playerTournaments:${id}`);
	if (cacheTournamentHistory) {
		return {
			playerResponse: playerResponse,
			slug: params.slug,
			tournamentHistory: JSON.parse(cacheTournamentHistory)
		};
	}

	const tournamentHistory = await userTournamentHistory(
		id,
		playerResponse.user.player.gamerTag,
		1,
		20
	);

	await jsonSet(`playerTournaments:${id}`, tournamentHistory);

	return {
		playerResponse: playerResponse,
		slug: params.slug,
		tournamentHistory: tournamentHistory
	};
};
