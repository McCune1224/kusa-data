import { getPlayer } from '$lib/startql/player';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	const playerId = +params.slug;
	const opponentId = +params.opponentId;

	let player, opponent;

	try {
		player = await getPlayer(playerId);
	} catch {
		player = { user: null };
	}

	try {
		opponent = await getPlayer(opponentId);
	} catch {
		opponent = { user: null };
	}

	return {
		player: player.user ? { id: playerId, gamerTag: player.user.player.gamerTag } : null,
		opponent: opponent.user ? { id: opponentId, gamerTag: opponent.user.player.gamerTag } : null
	};
};
