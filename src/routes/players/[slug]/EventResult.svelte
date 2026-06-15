<script lang="ts">
	import type { TournamentRecordEvent } from '$lib/startql/player';

	export let event: TournamentRecordEvent;
	export let gamerTag: string;

	function placementColorStyling(placement: number) {
		if (placement === 1) {
			return 'text-yellow-500';
		} else if (placement === 2) {
			return 'text-gray-500';
		} else if (placement === 3) {
			return 'text-amber-800';
		}
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
