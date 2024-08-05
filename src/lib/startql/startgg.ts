import { gql, GraphQLClient } from 'graphql-request';
import { ACCESS_TOKEN } from '$env/static/private';
import { parse } from 'graphql';
import type {
	TournamentEventData,
	TournamentEventResponse,
	TournamentParticipantCountResponse
} from './result_types';
import type { TypedDocumentNode } from '@graphql-typed-document-node/core';

const endpoint = 'https://api.start.gg/gql/alpha';

//You may not average more than 80 requests per 60 seconds.
//You are limited to a maximum of 1000 objects per request (this includes nested objects).
export const startggClient = new GraphQLClient(endpoint, {
	headers: {
		authorization: `Bearer ${ACCESS_TOKEN}`,
		// Highly recommended for graphql to use POST requests
		method: 'POST'
	}
});

export const getTournament = async (slug: string) => {
	const query: TypedDocumentNode<TournamentEventResponse> = parse(gql`
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

export const getTournamentParticipants = async (tourneySlug: string) => {
	const query: TypedDocumentNode<TournamentParticipantCountResponse> = parse(gql`
		query AttendeeCount($tourneySlug: String!) {
			tournament(slug: $tourneySlug) {
				id
				name
				participants(query: {}) {
					pageInfo {
						total
					}
				}
			}
		}
	`);
	const variables = {
		tourneySlug: tourneySlug
	};

	return await startggClient.request({ document: query, variables });
};

export const getFullTournamentParticipants = async (tourneySlug: string) => {
	const query: TypedDocumentNode<any> = parse(gql`
		query TournamentParticipants($tournamentSlug: String!) {
			tournament(slug: $tournamentSlug) {
				events {
					id
					name
					entrants(query: {}) {
						nodes {
							id
							name
							participants {
								id
								gamerTag
								user {
									id
									name
								}
							}
						}
					}
				}
			}
		}
	`);
	const variables = {};

	return await startggClient.request({ document: query, variables });
};
