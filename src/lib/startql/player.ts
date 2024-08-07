import { gql } from 'graphql-request';
import { startggClient } from './startgg';
import type { TypedDocumentNode } from '@graphql-typed-document-node/core';
import { parse } from 'graphql';

export type PlayerData = {
	player: {
		id: number;
		gamerTag: string;
	};
};
export type PlayerResponse = PlayerData | { player: null };

export const getPlayer = async (id: number) => {
	const query: TypedDocumentNode<PlayerResponse> = parse(gql`
		query getPlayer($id: ID!) {
			player(id: $id) {
				id
				gamerTag
			}
		}
	`);
	return await startggClient.request({ document: query, variables: { id: id } });
};

export const userTournamentHistory = async (id: number, page: number = 1, perPage: number = 10) => {
	const query: TypedDocumentNode<any> = parse(gql`
		query UserTournaments($id: ID!, $page: Int, $perPage: Int) {
			user(id: $id) {
				tournaments(query: { page: $page, perPage: $perPage }) {
					nodes {
						id
						name
						slug
						startAt
						endAt
					}
					pageInfo {
						total
					}
				}
			}
		}
	`);
	return await startggClient.request({
		document: query,
		variables: { id: id, page: page, perPage: perPage }
	});
};
