export type TournamentEventData = {
	event: {
		id: number;
		name: string;
	};
};

export type TournamentEventResponse = TournamentEventData | { event: null };

export type TournamentParticipantCountData = {
	tournament: {
		id: number;
		name: string;
		participants: {
			pageInfo: {
				total: number;
			};
		};
	};
};

export type TournamentParticipantCountResponse =
	| TournamentParticipantCountData
	| { tournament: null };
