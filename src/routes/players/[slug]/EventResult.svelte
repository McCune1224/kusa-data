<script lang="ts">
	import type { PlayerEventStandingResponse, TournamentRecordEvent } from '$lib/startql/player';
	import { onMount } from 'svelte';
	import { writable } from 'svelte/store';

	export let event: TournamentRecordEvent;
	export let gamerTag: string;

	const eventRecord = writable<PlayerEventStandingResponse>();

	function placementColorStyling(placement: number) {
		if (placement === 1) {
			return 'text-yellow-500';
		} else if (placement === 2) {
			return 'text-gray-500';
		} else if (placement === 3) {
			return 'text-brown-500';
		} else placement === 4;
		return '';
	}
</script>

{#each event.entrants.nodes as placement}
	{#if placement.standing}
		<div class="border-2 border-primary p-3">
			{event.name}
			<div class="flex flex-row gap-2">
				<p class={placementColorStyling(placement.standing.placement)}>
					{placement.standing.placement}
				</p>
				<p>
					/ {event.numEntrants}
				</p>
			</div>
		</div>
	{/if}
{/each}
