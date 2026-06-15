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

// --- Set/Match types ---

export type SetSlot = {
	id: number;
	entrant: { id: number; name: string } | null;
	standing: {
		id: number;
		placement: number;
		stats: { score: { value: number } } | null;
	} | null;
};

export type GameSelection = {
	entrant: { id: number };
	selectionType: string | null;
	character: { id: number; name: string } | null;
};

export type Game = {
	orderNum: number;
	winnerId: number | null;
	stage: { id: number; name: string } | null;
	selections: GameSelection[];
	entrant1Score: number | null;
	entrant2Score: number | null;
};

export type Set = {
	id: number;
	displayScore: string | null;
	fullRoundText: string | null;
	state: number;
	completedAt: string | null;
	vodUrl: string | null;
	event: { id: number; name: string; slug: string };
	slots: SetSlot[];
	games: Game[];
};

export type PlayerSetsResponse = {
	player: {
		id: number;
		gamerTag: string;
		sets: {
			nodes: Set[];
			pageInfo: { total: number; totalPages: number };
		};
	};
};
