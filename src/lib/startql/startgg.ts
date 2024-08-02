import { gql, GraphQLClient } from 'graphql-request';
import { ACCESS_TOKEN } from '$env/static/private';
import { parse } from 'graphql';
import type { TournamentEventData, TournamentEventResponse } from './result_types';
import type { TypedDocumentNode } from '@graphql-typed-document-node/core';

const endpoint = 'https://api.start.gg/gql/alpha';

//You may not average more than 80 requests per 60 seconds.
//You are limited to a maximum of 1000 objects per request (this includes nested objects).
export const startggClient = new GraphQLClient(endpoint, {
	headers: {
		authorization: `Bearer ${ACCESS_TOKEN}`,
		// Highly recommended to set this header to prevent CORS issues
		method: 'POST'
	}
});

// export const getTournament = async (slug: string) => {
// 	const query = gql`
// 		query getEventId($slug: String) {
// 			event(slug: $slug) {
// 				id
// 				name
// 			}
// 		}
// 	`;
//
// 	const variables = {
// 		slug: slug
// 	};
//
// 	return startggClient.request<TournamentEventData>(query, variables);
// };

export const getTournament = async (slug: string) => {
	const query: TypedDocumentNode<{ tournament: TournamentEventResponse }> = parse(gql`
		query getEventId($slug: String) {
			event(slug: $slug) {
				id
				name
			}
		}
	`);
	const variables = {
		slug: `tournament/${slug}/event/smash-ultimate-singles`
	};

	return await startggClient.request({ document: query, variables });
};
