import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getTournament } from '$lib/startql/startgg';

export const GET: RequestHandler = async (event) => {
	const name = event.params.slug;

	const result = await getTournament(name);
	return json(result);
};
