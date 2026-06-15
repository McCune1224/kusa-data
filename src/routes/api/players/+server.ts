import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { searchPlayers } from '$lib/startql/player';

export const GET: RequestHandler = async (event) => {
	const name = event.url.searchParams.get('name');

	if (!name || name.trim().length === 0) {
		return json({ players: [] });
	}

	try {
		const result = await searchPlayers(name.trim());
		const players = (result.users?.nodes ?? [])
			.filter((n) => n.player !== null)
			.map((n) => ({
				id: n.id,
				gamerTag: n.player!.gamerTag,
				prefix: n.player!.prefix,
				image: n.images?.[0]?.url ?? null
			}));
		return json({ players });
	} catch (e) {
		console.error('Player search failed:', e);
		return json({ players: [] });
	}
};
