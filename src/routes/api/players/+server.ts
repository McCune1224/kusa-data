import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async (event) => {
	const queryParams = new URLSearchParams(event.url.search);
	const name = queryParams.get('name');

	return json({ params: queryParams.get('name'), player: null });
};
