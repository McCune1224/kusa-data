// export interface EmptyResult {}

export interface TournamentEventData {
	event: {
		id: number;
		name: string;
	};
}

export interface NullTournamentEventData {
	event: null;
}

export type TournamentEventResponse = TournamentEventData | NullTournamentEventData;
