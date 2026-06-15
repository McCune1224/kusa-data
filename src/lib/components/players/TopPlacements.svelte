<script lang="ts">
	export let placements: {
		placement: number;
		tournamentName: string;
		numEntrants: number | null;
	}[] = [];

	$: top = [...placements].sort((a, b) => a.placement - b.placement).slice(0, 10);

	function placementClass(p: number): string {
		if (p === 1) return 'text-yellow-500';
		if (p === 2) return 'text-gray-400';
		if (p === 3) return 'text-amber-800';
		return '';
	}
</script>

<div class="card border bg-base-200">
	<div class="card-body">
		<h2 class="card-title">Top Placements</h2>

		{#if placements.length === 0}
			<p class="py-4 text-center text-muted-foreground">No placement data yet.</p>
		{:else}
			<div class="overflow-x-auto">
				<table class="table table-zebra table-xs">
					<thead>
						<tr>
							<th class="w-12">#</th>
							<th>Event</th>
							<th class="text-right">Entrants</th>
						</tr>
					</thead>
					<tbody>
						{#each top as p}
							<tr>
								<td class="text-lg font-bold {placementClass(p.placement)}">
									{p.placement}
								</td>
								<td class="max-w-48 truncate">{p.tournamentName}</td>
								<td class="text-right text-muted-foreground">
									{p.numEntrants ?? '?'}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</div>
</div>
