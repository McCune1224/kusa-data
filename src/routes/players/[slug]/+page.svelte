<script lang="ts">
	import type { PlayerTournamentRecord } from '$lib/startql/player';
	import { writable } from 'svelte/store';
	import type { PageServerData } from './$types';
	import EventResult from './EventResult.svelte';
	export let data: PageServerData;
	const user = data.playerResponse.user;
	const tournamentHistory = writable<PlayerTournamentRecord[]>();
	if (data.tournamentHistory) {
		tournamentHistory.set(
			data.tournamentHistory.user.tournaments.nodes
				.filter((t) => t.events.length > 0)
				.sort((a, b) => b.id - a.id)
		);
	}
</script>

<main>
	{#if user}
		<div class="flex flex-row gap-4 items-center">
			<img
				class="border-4 rounded-full shadow-lg"
				src={data.tournamentHistory?.user.images.length == 2
					? data.tournamentHistory?.user.images[1].url
					: data.tournamentHistory?.user.images[0].url}
				height="100"
				width="100"
				alt=""
			/>
			<h1 class="text-7xl">{user.player.gamerTag}</h1>
		</div>

		<div class="p-4 grid grid-cols-3 gap-4">
			{#each $tournamentHistory as tournament}
				<div class="flex flex-col border-4">
					<p>{tournament.name}</p>
					{#each tournament.events as event}
						<div class="flex flex-col border-2">
							<EventResult {event} gamerTag={user.player.gamerTag} />
						</div>
					{/each}
				</div>
			{/each}
		</div>
	{:else}
		<h1 class="text-7xl">Player not found with id {data.slug}</h1>
	{/if}
</main>
