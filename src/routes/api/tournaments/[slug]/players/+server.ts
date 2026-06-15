import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getFullTournamentParticipants } from '$lib/startql/startgg';

export const GET: RequestHandler = async (event) => {
	const name = event.params.slug;

	try {
		const result = await getFullTournamentParticipants(name);
		return json(result);
	} catch (e) {
		console.error('Failed to fetch tournament participants:', e);
		return json({ tournament: null });
	}
};
