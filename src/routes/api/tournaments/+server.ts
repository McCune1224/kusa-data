import { json } from '@sveltejs/kit';
import type { RequestHandler } from '../$types';

export const GET: RequestHandler = async (event) => {
	event.params;
	return json(200, {});
};
