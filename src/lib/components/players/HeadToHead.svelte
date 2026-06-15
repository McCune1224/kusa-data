<script lang="ts">
	let opponentQuery = '';
	let searching = false;
	let opponent: { id: number; gamerTag: string; prefix: string | null } | null = null;
	let error = '';

	async function searchOpponent() {
		const q = opponentQuery.trim();
		if (!q) return;
		searching = true;
		error = '';
		try {
			const res = await fetch(`/api/players?name=${encodeURIComponent(q)}`);
			const data = await res.json();
			const players = data.players ?? [];
			if (players.length === 0) {
				error = 'No players found.';
				opponent = null;
			} else {
				opponent = players[0];
			}
		} catch {
			error = 'Search failed.';
			opponent = null;
		}
		searching = false;
	}

	function clearOpponent() {
		opponent = null;
		opponentQuery = '';
	}
</script>

<div class="card border bg-base-200">
	<div class="card-body">
		<h2 class="card-title">Head-to-Head</h2>

		{#if opponent}
			<div class="flex items-center gap-3 rounded-lg border p-3">
				<div class="flex-1">
					<span class="font-semibold">{opponent.gamerTag}</span>
					{#if opponent.prefix}
						<span class="ml-1 text-sm text-muted-foreground">| {opponent.prefix}</span>
					{/if}
				</div>
				<a href="/players/{opponent.id}" class="btn btn-ghost btn-sm"> View Profile </a>
				<button class="btn btn-ghost btn-sm" on:click={clearOpponent}>Clear</button>
			</div>
		{:else}
			<form class="join w-full" on:submit|preventDefault={searchOpponent}>
				<input
					type="text"
					class="input input-bordered join-item flex-1"
					placeholder="Opponent gamer tag"
					bind:value={opponentQuery}
				/>
				<button type="submit" class="btn btn-primary join-item" disabled={searching}>
					{searching ? '...' : 'Search'}
				</button>
			</form>
			{#if error}
				<p class="mt-2 text-sm text-error">{error}</p>
			{/if}
		{/if}
	</div>
</div>
