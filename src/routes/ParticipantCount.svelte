<script lang="ts">
	import type { TournamentParticipantCountResponse } from '$lib/startql/result_types';
	import { writable } from 'svelte/store';

	const resultError = writable<string>();
	const tournamentName = writable<string>('tech-chase-tuesday-13');
	const tournamentInfo = writable<TournamentParticipantCountResponse>();
	const loading = writable<boolean>(false);

	async function searchTournamentParticipants(name: string) {
		loading.set(true);
		resultError.set('');
		console.log(name);
		const resp = await fetch(`/api/tournaments/${name}/players`);
		const result: TournamentParticipantCountResponse = await resp.json();
		console.log(result);
		if (result.tournament === null) {
			resultError.set('No tournament found of name ' + name);
		} else {
			tournamentInfo.set(result);
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
					tournamentName.set($tournamentName.replace(/\s+/g, '-'));
					searchTournamentParticipants($tournamentName);
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
		<div class="gap-3 border-2 border-primary bg-base-300 rounded-lg p-4 flex flex-col">
			<p class="text-2xl font-bold">
				{$tournamentInfo.tournament?.name} ({$tournamentInfo.tournament?.participants.pageInfo
					.total} players)
			</p>
			<a href="#" class="btn">View All Players</a>
			<a target="_blank" href={`https://start.gg/tournament/${$tournamentName}/details`} class="btn"
				>View on start.gg</a
			>
		</div>
	{/if}
</div>
