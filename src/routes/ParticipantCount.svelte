<script lang="ts">
	import type { TournamentParticipantCountResponse } from '$lib/startql/result_types';
	import { writable } from 'svelte/store';

	const resultError = writable<string>();
	const tournamentName = writable<string>('tech-chase-tuesday-13');
	const tournamentInfo = writable<TournamentParticipantCountResponse>();

	async function searchTournamentParticipants(name: string) {
		resultError.set('');
		const resp = await fetch(`/api/tournaments/${$tournamentName}/players`);
		const result: TournamentParticipantCountResponse = await resp.json();
		console.log(result);
		if (result.tournament === null) {
			resultError.set('No tournament found of name ' + name);
		} else {
			tournamentInfo.set(result);
		}
	}
</script>

<div class="flex flex-col">
	<div class="mt-6 flex flex-row justify-center">
		<div class="join">
			<div>
				<div>
					<input
						class="input input-bordered join-item"
						value={$tournamentName}
						on:input={(e) => {
							//@ts-ignore I hate you events
							tournamentName.set(e.target.value);
						}}
					/>
				</div>
			</div>
			<button on:click={() => searchTournamentParticipants($tournamentName)} class="btn join-item"
				>Search</button
			>
		</div>
		{#if $tournamentInfo}
			<div class="flex flex-col">
				<p>{$tournamentInfo.tournament?.name}</p>
				<p>{$tournamentInfo.tournament?.participants.pageInfo.total}</p>
			</div>
		{/if}
	</div>
</div>
