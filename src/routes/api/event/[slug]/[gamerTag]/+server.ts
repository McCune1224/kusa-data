import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getEntrantStanding } from '$lib/startql/player';

export const GET: RequestHandler = async (event) => {
	const eventID = +event.params.slug;
	const gamerTag = event.params.gamerTag;

	if (isNaN(eventID)) {
		return json({ event: null });
	}

	try {
		const response = await getEntrantStanding(eventID, gamerTag);
		return json({ response });
	} catch (e) {
		console.error('Failed to fetch entrant standing:', e);
		return json({ event: null });
	}
};
