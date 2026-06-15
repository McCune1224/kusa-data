import { getPlayer, resolveGamerTag, userTournamentHistory } from '$lib/startql/player';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import redisClient, { jsonSet } from '$lib/redisClient';

export const load: PageServerLoad = async ({ params }) => {
	const id = +params.slug;

	if (isNaN(id)) {
		// Try to resolve as a gamer tag
		try {
			const resolved = await resolveGamerTag(params.slug);
			if (resolved) {
				throw redirect(307, `/players/${resolved.id}`);
			}
		} catch (e) {
			if (e instanceof Response) throw e; // re-throw redirect
			console.error('Failed to resolve gamer tag:', e);
		}
		return { playerResponse: { user: null }, slug: params.slug, tournamentHistory: null };
	}

	let playerResponse;
	try {
		playerResponse = await getPlayer(id);
	} catch (e) {
		console.error('Failed to fetch player:', e);
		return { playerResponse: { user: null }, slug: params.slug, tournamentHistory: null };
	}
	if (playerResponse.user === null) {
		return { playerResponse: { user: null }, slug: params.slug, tournamentHistory: null };
	}

	const cacheTournamentHistory = await redisClient.get(`playerTournaments:${id}`);
	if (cacheTournamentHistory) {
		return {
			playerResponse: playerResponse,
			slug: params.slug,
			tournamentHistory: JSON.parse(cacheTournamentHistory)
		};
	}

	let tournamentHistory;
	try {
		tournamentHistory = await userTournamentHistory(
			id,
			playerResponse.user.player.gamerTag,
			1,
			100
		);

		const totalPages = tournamentHistory.user.tournaments.pageInfo.totalPages;
		if (totalPages > 1) {
			const remainingPages = Array.from({ length: totalPages - 1 }, (_, i) => i + 2);
			const pageResults = await Promise.all(
				remainingPages.map((page) =>
					userTournamentHistory(id, playerResponse.user.player.gamerTag, page, 100)
				)
			);
			for (const pageResult of pageResults) {
				tournamentHistory.user.tournaments.nodes.push(...pageResult.user.tournaments.nodes);
			}
		}

		await jsonSet(`playerTournaments:${id}`, tournamentHistory);
	} catch (e) {
		console.error('Failed to fetch tournament history:', e);
		return { playerResponse: playerResponse, slug: params.slug, tournamentHistory: null };
	}

	return {
		playerResponse: playerResponse,
		slug: params.slug,
		tournamentHistory: tournamentHistory
	};
};
