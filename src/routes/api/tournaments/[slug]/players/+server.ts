import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getTournamentParticipants } from '$lib/startql/startgg';

export const GET: RequestHandler = async (event) => {
	const name = event.params.slug;
	const result = await getTournamentParticipants(name);
	return json(result);
};
