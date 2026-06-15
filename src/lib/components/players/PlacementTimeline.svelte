<script lang="ts">
	export let placements: {
		tournamentName: string;
		placement: number;
		numEntrants: number | null;
	}[] = [];

	$: recent = [...placements].reverse().slice(-20);
	$: maxPlacement = Math.max(...recent.map((p) => p.placement), 1);
	$: chartHeight = 120;

	function barHeight(p: number): number {
		return Math.max(4, Math.round((1 - p / maxPlacement) * chartHeight));
	}
</script>

<div class="card border bg-base-200">
	<div class="card-body">
		<h2 class="card-title">Placement Timeline (last 20)</h2>

		{#if placements.length === 0}
			<p class="py-4 text-center text-muted-foreground">No placement data yet.</p>
		{:else}
			<div class="flex items-end gap-1" style="height: {chartHeight + 30}px">
				{#each recent as p, i}
					<div
						class="tooltip tooltip-top flex flex-1 flex-col items-center"
						data-tip="{p.placement}/{p.numEntrants ?? '?'} — {p.tournamentName}"
					>
						<div
							class="w-full rounded-t-sm transition-all {p.placement === 1
								? 'bg-yellow-500'
								: p.placement <= 3
									? 'bg-amber-800'
									: p.placement <= 8
										? 'bg-primary'
										: 'bg-base-300'}"
							style="height: {barHeight(p.placement)}px"
						></div>
						<span class="mt-1 text-[10px] text-muted-foreground">{i + 1}</span>
					</div>
				{/each}
			</div>
			<p class="mt-2 text-xs text-muted-foreground">
				Each bar = one event. Hover for details. Lower = better.
			</p>
		{/if}
	</div>
</div>
