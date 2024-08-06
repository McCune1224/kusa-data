import { getFullTournamentParticipants } from '$lib/startql/startgg';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	const name = params.slug;
	const result = await getFullTournamentParticipants(name);
	console.log(result.tournament?.events[0]?.entrants.nodes[0]?.participants[0].gamerTag);
	return { params, result };
};
