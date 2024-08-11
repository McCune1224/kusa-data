import { json } from '@sveltejs/kit';
import type { RequestHandler } from '../$types';

export const GET: RequestHandler = async (event) => {
	eventID = event.params.slug;

	return json({});
};
