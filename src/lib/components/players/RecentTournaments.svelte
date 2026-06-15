<script lang="ts">
	export let tournaments: {
		id: number;
		name: string;
		slug: string;
		events: {
			id: number;
			name: string;
			numEntrants: number;
			slug: string;
			entrants: { nodes: { standing: { placement: number } }[] };
		}[];
	}[] = [];

	function placementClass(p: number): string {
		if (p === 1) return 'text-yellow-500';
		if (p === 2) return 'text-gray-400';
		if (p === 3) return 'text-amber-800';
		return '';
	}
</script>

<div class="card border bg-base-200">
	<div class="card-body">
		<h2 class="card-title">Recent Tournaments</h2>

		{#if tournaments.length === 0}
			<p class="py-4 text-center text-muted-foreground">No tournaments found.</p>
		{:else}
			<div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
				{#each tournaments as tournament}
					<div class="card border bg-base-100">
						<div class="card-body p-3">
							<a
								href="https://start.gg/{tournament.slug}"
								target="_blank"
								class="link link-hover font-semibold"
							>
								{tournament.name}
							</a>
							{#each tournament.events as event}
								<div class="border-2 border-primary p-3">
									{event.name}
									<div class="flex flex-row gap-2">
										{#each event.entrants.nodes as node}
											{#if node.standing}
												<p class={placementClass(node.standing.placement)}>
													{node.standing.placement}
												</p>
												<p>/ {event.numEntrants}</p>
											{/if}
										{/each}
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>
