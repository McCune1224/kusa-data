import { gql } from 'graphql-request';
import { startggClient } from './startgg';
import type { TypedDocumentNode } from '@graphql-typed-document-node/core';
import { parse } from 'graphql';

export type PlayerData = {
	user: {
		player: {
			id: number;
			gamerTag: string;
		};
	};
};
export type PlayerResponse = PlayerData | { user: null };

export const getPlayer = async (id: number) => {
	const query: TypedDocumentNode<PlayerResponse> = parse(gql`
		query GetPlayer($id: ID!) {
			user(id: $id) {
				id
				player {
					gamerTag
				}
			}
		}
	`);
	return await startggClient.request({ document: query, variables: { id: id } });
};

export type EventEntrantStanding = {
	nodes: {
		standing: {
			placement: number;
		};
	}[];
};
export type TournamentRecordEvent = {
	id: number;
	name: string;
	numEntrants: number;
	slug: number;
	entrants: EventEntrantStanding;
};
export type PlayerTournamentRecord = {
	id: number;
	name: string;
	slug: string;
	events: TournamentRecordEvent[];
};

export type PlayerTournamentUser = {
	name: string;
	id: number;
	player: {
		id: number;
		gamerTag: string;
	};
	images: {
		id: number;
		height: number;
		width: number;
		url: string;
	};
};

export type PlayerHistoryResponse = {
	user: {
		name: string;
		id: number;
		player: {
			id: number;
			gamerTag: string;
		};
		images: {
			id: number;
			height: number;
			width: number;
			url: string;
		}[];
		tournaments: {
			nodes: PlayerTournamentRecord[];
			pageInfo: { total: number; totalPages: number };
		};
	};
};

export const userTournamentHistory = async (
	id: number,
	gamerTag: string,
	page: number = 1,
	perPage: number = 100
) => {
	const query: TypedDocumentNode<PlayerHistoryResponse> = parse(gql`
		query UserTournaments($id: ID!, $gamerTag: String!, $page: Int, $perPage: Int) {
			user(id: $id) {
				name
				id
				player {
					id
					gamerTag
				}
				images(type: "") {
					id
					height
					width
					url
				}
				tournaments(query: { page: $page, perPage: $perPage }) {
					nodes {
						id
						name
						slug
						events(filter: { videogameId: 1386 }) {
							id
							name
							numEntrants
							entrants(query: { filter: { name: $gamerTag } }) {
								nodes {
									standing {
										placement
									}
								}
							}
						}
					}
					pageInfo {
						total
						totalPages
					}
				}
			}
		}
	`);
	return await startggClient.request({
		document: query,
		variables: { id: id, gamerTag: gamerTag, page: page, perPage: perPage }
	});
};

export type EntrantEventStanding = {
	standing: {
		id: number;
		placement: number;
		isFinal: boolean;
	};
};
export type PlayerEventStandingResponse = {
	event:
		| {
				numEntrants: number;
				nodes: {
					standing: EntrantEventStanding;
				}[];
		  }
		| { event: null };
};

export const getEntrantStanding = async (eventID: number, entrantName: string) => {
	const query: TypedDocumentNode<PlayerEventStandingResponse> = parse(gql`
		query GetEntrantForEvent($eventID: ID!, $entrantName: String) {
			event(id: $eventID) {
				numEntrants
				entrants(query: { filter: { name: $entrantName } }) {
					nodes {
						standing {
							id
							placement
							isFinal
						}
					}
				}
			}
		}
	`);
	return await startggClient.request({
		document: query,
		variables: { eventID: eventID, entrantName: entrantName }
	});
};
