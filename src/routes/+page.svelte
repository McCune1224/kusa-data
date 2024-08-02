<script lang="ts">
	import { writable } from 'svelte/store';
	import type { ActionData } from './$types';
	import type { TournamentEventData, TournamentEventResponse } from '$lib/startql/result_types';

	let tournamentName = writable('tech-chase-tuesday-78');
	let tournamentResult = writable<TournamentEventData>();
	let resultError = writable<string>();

	async function searchTournament(name: string) {
		tournamentResult.set(null);
		const resp = await fetch(`/api/tournaments/${$tournamentName}`);
		const tournament: TournamentEventResponse = await resp.json();
		console.log(tournament);
		if (tournament.event === null) {
			resultError.set('No tournament found of name ' + name);
		} else {
			tournamentResult.set(tournament);
		}
	}
</script>

<main class="text-9xl pt-2 p-4">
	<input type="text" bind:value={$tournamentName} placeholder="Tournament Name" />
	{#if $resultError}
		<div class="text-red-500">{$resultError}</div>
	{/if}
	<button
		on:click={() => {
			searchTournament($tournamentName);
		}}>Search</button
	>
	{#if $tournamentResult}
		<h2>{$tournamentResult.event.id}</h2>
		<h2>{$tournamentResult.event.name}</h2>
	{/if}
</main>
