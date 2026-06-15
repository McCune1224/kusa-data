import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { getPlayerSets } from '$lib/startql/player';

export const GET: RequestHandler = async (event) => {
	const playerId = +event.params.id;
	const page = +(event.url.searchParams.get('page') ?? '1');
	const perPage = Math.min(+(event.url.searchParams.get('perPage') ?? '25'), 50);

	if (isNaN(playerId)) {
		return json({ sets: [], pageInfo: { total: 0, totalPages: 0 } });
	}

	try {
		const result = await getPlayerSets(playerId, page, perPage);
		return json(result.player.sets);
	} catch (e) {
		console.error('Failed to fetch player sets:', e);
		return json({ sets: [], pageInfo: { total: 0, totalPages: 0 } });
	}
};
