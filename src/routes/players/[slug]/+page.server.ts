import { getPlayer, userTournamentHistory } from '$lib/startql/player';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	const id = +params.slug;
	if (isNaN(id)) {
		return { playerResponse: { player: null }, slug: params.slug };
	}

	const playerResponse = await getPlayer(+params.slug);
	console.log(playerResponse);
	const foo = await userTournamentHistory(id);
	console.log(foo);
	return { playerResponse: playerResponse, slug: params.slug };
};
