import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getEntrantStanding } from '$lib/startql/player';

export const GET: RequestHandler = async (event) => {
	const eventID = +event.params.slug;
	const gamerTag = event.params.gamerTag;

	if (isNaN(eventID)) {
		return json({ event: null });
	}

	const response = await getEntrantStanding(eventID, gamerTag);
	console.log(response);

	return json({ response });
};
