<script lang="ts">
	export let characters: {
		name: string;
		gamesPlayed: number;
		gamesWon: number;
		winRate: number;
		usagePercent: number;
	}[] = [];
	export let totalGames: number = 0;

	$: topChars = characters.slice(0, 10);
	$: maxGames = Math.max(...topChars.map((c) => c.gamesPlayed), 1);
</script>

<div class="card border bg-base-200">
	<div class="card-body">
		<h2 class="card-title">
			Character Usage
			{#if totalGames > 0}
				<span class="text-sm font-normal text-muted-foreground">({totalGames} games)</span>
			{/if}
		</h2>

		{#if characters.length === 0}
			<p class="py-4 text-center text-muted-foreground">No character data available.</p>
		{:else}
			<div class="space-y-3">
				{#each topChars as char}
					<div>
						<div class="mb-1 flex justify-between text-sm">
							<span class="font-medium">{char.name}</span>
							<span class="text-muted-foreground">
								{char.gamesPlayed}g ({char.winRate}%)
							</span>
						</div>
						<div class="h-2 w-full rounded-full bg-base-300">
							<div
								class="h-2 rounded-full bg-primary transition-all"
								style="width: {(char.gamesPlayed / maxGames) * 100}%"
							></div>
						</div>
					</div>
				{/each}
			</div>
			{#if characters.length > 10}
				<p class="mt-2 text-center text-xs text-muted-foreground">
					+{characters.length - 10} more characters
				</p>
			{/if}
		{/if}
	</div>
</div>
