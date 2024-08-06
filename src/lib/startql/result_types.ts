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

export type User = {
	id: number;
	name: string | null;
	genderPronoun: string | null;
};

export type Participant = {
	id: number;
	gamerTag: string;
	user: User;
};

export type EntrantNode = {
	participants: Participant[];
};

export type Entrants = {
	nodes: EntrantNode[];
};

export type Videogame = {
	id: number;
	name: string;
};

export type Event = {
	id: number;
	name: string;
	videogame: Videogame;
	entrants: Entrants;
};

export type Tournament = {
	events: Event[];
};

export type TournamentParticipantsData = {
	tournament: Tournament;
};

export type TournamentParticipantResponse = TournamentParticipantsData | { tournament: null };
