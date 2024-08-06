import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getFullTournamentParticipants } from '$lib/startql/startgg';

export const GET: RequestHandler = async (event) => {
	const name = event.params.slug;
	const result = await getFullTournamentParticipants(name);
	return json(result);
};
