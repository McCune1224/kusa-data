<script lang="ts">
	import { writable } from 'svelte/store';
	import type { ActionData } from './$types';
	import type {
		TournamentParticipantCountData,
		TournamentParticipantCountResponse
	} from '$lib/startql/result_types';
	import { onMount } from 'svelte';

	let tournamentName = writable('tech-chase-tuesday-78');
	let resultError = writable<string>();
	let dumpy = writable<TournamentParticipantCountData>();

	// async function searchTournament(name: string) {
	// 	tournamentResult.set();
	// 	resultError.set('');
	// 	const resp = await fetch(`/api/tournaments/${$tournamentName}`);
	// 	const tournament: TournamentEventResponse = await resp.json();
	// 	if (tournament.event === null) {
	// 		resultError.set('No tournament found of name ' + name);
	// 	} else {
	// 		tournamentResult.set(tournament);
	// 	}
	// }

	async function searchTournamentParticipants(name: string) {
		resultError.set('');
		const resp = await fetch(`/api/tournaments/${$tournamentName}/players`);
		const result: TournamentParticipantCountResponse = await resp.json();
		if (result.tournament === null) {
			resultError.set('No tournament found of name ' + name);
		} else {
			dumpy.set(result);
		}
	}

	onMount(async () => {
		searchTournamentParticipants('tech-chase-tuesday-78');
	});
</script>

<main class="text-9xl pt-2 p-4">
	<input type="text" bind:value={$tournamentName} placeholder="Tournament Name" />
	{#if $resultError}
		<div class="text-red-500">{$resultError}</div>
	{/if}
	<button
		on:click={() => {
			searchTournamentParticipants($tournamentName);
		}}>Search</button
	>
	{#if $dumpy}
		<h2>{$dumpy.tournament.id}</h2>
		<h2>{$dumpy.tournament.name}</h2>
		<h2>Total Players: {$dumpy.tournament.participants.pageInfo.total}</h2>
	{/if}
</main>
