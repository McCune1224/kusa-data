<script lang="ts">
	import type {
		TournamentEventData,
		TournamentEventResponse,
		TournamentParticipantCountData,
		TournamentParticipantCountResponse
	} from '$lib/startql/result_types';
	import { writable } from 'svelte/store';

	const resultError = writable<string>();
	const tournamentName = writable<string>('tech-chase-tuesday-13');
	const tournamentInfo = writable<TournamentEventData>();
	const loading = writable<boolean>(false);

	function parseTournamentSlug(url: string) {
		//Needs to handle:
		// https://www.start.gg/tournament/tech-chase-tuesday-63
		// https://www.start.gg/tournament/tech-chase-tuesday-63/events

		let isStartGg = url.includes('start.gg');
		if (isStartGg) {
			const split = url.split('/');
			const end = split.pop();
			if (end === 'events') {
				return split.pop();
			} else {
				return end;
			}
		}
		return url;
	}

	async function searchTournament(name: string) {
		const search = parseTournamentSlug(name);
		console.log(search);
		loading.set(true);
		resultError.set('');
		const resp = await fetch(`/api/tournaments/${search}`);
		const result: TournamentEventResponse = await resp.json();
		console.log(result);
		if (result.event === null) {
			resultError.set('No tournament found of name ' + search);
		} else {
			tournamentInfo.set(result);
			tournamentName.set(search as string);
		}
		loading.set(false);
	}
</script>

<div class="mt-6 flex flex-col gap-20 justify-center">
	<div class="join flex-flex-row justify-center">
		<input
			class="input input-bordered join-item"
			value={$tournamentName}
			on:input={(e) => {
				//@ts-ignore I hate you events
				tournamentName.set(e.target.value);
			}}
		/>
		{#if !$loading}
			<button
				on:click={() => {
					//convert all whitespace to dashes first:
					// tournamentName.set($tournamentName.replace(/\s+/g, '-'));
					searchTournament($tournamentName);
				}}
				class="btn join-item">Search</button
			>
		{:else}
			<button class="btn">
				<span class="loading loading-spinner"></span>
				searching
			</button>
		{/if}
	</div>
	{#if $tournamentInfo}
		<div class="gap-3 border-2 border-primary rounded-lg p-4 flex flex-col">
			<p class="text-2xl font-bold">
				{$tournamentInfo.event.name}
			</p>
			<a href={'tournaments/' + $tournamentName} class="btn btn-outline">View All Players</a>
			<a
				class="btn btn-outline"
				target="_blank"
				href={`https://start.gg/tournament/${$tournamentName}/details`}>View on start.gg</a
			>
		</div>
	{/if}
</div>
