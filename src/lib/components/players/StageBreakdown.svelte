<script lang="ts">
	export let stages: { name: string; gamesPlayed: number; gamesWon: number; winRate: number }[] =
		[];
	export let totalGames: number = 0;

	$: topStages = stages.slice(0, 8);
	$: maxGames = Math.max(...topStages.map((s) => s.gamesPlayed), 1);
</script>

<div class="card border bg-base-200">
	<div class="card-body">
		<h2 class="card-title">
			Stage Stats
			{#if totalGames > 0}
				<span class="text-sm font-normal text-muted-foreground">({totalGames} games)</span>
			{/if}
		</h2>

		{#if stages.length === 0}
			<p class="py-4 text-center text-muted-foreground">No stage data available.</p>
		{:else}
			<div class="overflow-x-auto">
				<table class="table table-zebra table-xs">
					<thead>
						<tr>
							<th>Stage</th>
							<th class="text-right">Games</th>
							<th class="text-right">W</th>
							<th class="text-right">L</th>
							<th class="text-right">Win %</th>
						</tr>
					</thead>
					<tbody>
						{#each topStages as stage}
							<tr>
								<td class="font-medium">{stage.name}</td>
								<td class="text-right">{stage.gamesPlayed}</td>
								<td class="text-right text-success">{stage.gamesWon}</td>
								<td class="text-right text-error">{stage.gamesPlayed - stage.gamesWon}</td>
								<td class="text-right">{stage.winRate}%</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			{#if stages.length > 8}
				<p class="mt-2 text-center text-xs text-muted-foreground">
					+{stages.length - 8} more stages
				</p>
			{/if}
		{/if}
	</div>
</div>
