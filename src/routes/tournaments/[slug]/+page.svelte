<script lang="ts">
	import type { PageData } from './$types';
	import PlayerCard from './PlayerCard.svelte';
	export let data: PageData;

	const singlesEvent = data.result.tournament.events.find((event) => event.videogame.id === 1386);
</script>

<main class="flex items-center justify-center bg-background px-6">
	<div class="flex flex-col">
		{#if singlesEvent}
			<h1 class="text-7xl">{data.params.slug}</h1>
			<p>{singlesEvent.name}</p>
			<p>{singlesEvent.id}</p>
			<div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
				{#each singlesEvent.entrants.nodes as pc}
					<PlayerCard player={pc.participants[0]} />
				{/each}
			</div>
		{:else}
			<div class="min-h-[100dvh] items-center justify-center bg-background flex flex-col gap-10">
				<h1 class="text-7xl">{data.params.slug}</h1>
				<h2 class="text-4xl">Bummer, no Smash Ultimate Events found...</h2>
				<a href="/" class="btn btn-outline">Go Home</a>
			</div>
		{/if}
	</div>
</main>
