import { getFullTournamentParticipants } from '$lib/startql/startgg';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	const name = params.slug;
	try {
		const result = await getFullTournamentParticipants(name);
		return { params, result };
	} catch (e) {
		console.error('Failed to fetch tournament participants:', e);
		return { params, result: { tournament: null } };
	}
};
