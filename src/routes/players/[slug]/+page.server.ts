import { getPlayer, userTournamentHistory, type PlayerTournamentUser } from '$lib/startql/player';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	const id = +params.slug;
	if (isNaN(id)) {
		return { playerResponse: { user: null }, slug: params.slug, tournamentHistory: null };
	}

	const playerResponse = await getPlayer(+params.slug);
	if (playerResponse.user === null) {
		return { playerResponse: { user: null }, slug: params.slug, tournamentHistory: null };
	}

	const tournamentHistory = await userTournamentHistory(
		id,
		playerResponse.user.player.gamerTag,
		1,
		20
	);
	return {
		playerResponse: playerResponse,
		slug: params.slug,
		tournamentHistory: tournamentHistory
	};
};
