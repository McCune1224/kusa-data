<script lang="ts">
	import { goto } from '$app/navigation';

	let query = '';
	let searching = false;
	let results: { id: number; gamerTag: string; prefix: string | null }[] = [];
	let error = '';

	async function search() {
		const q = query.trim();
		if (!q) return;
		searching = true;
		error = '';
		try {
			const res = await fetch(`/api/players?name=${encodeURIComponent(q)}`);
			const data = await res.json();
			results = (data.players ?? []).slice(0, 10);
			if (results.length === 0) error = 'No players found.';
		} catch {
			error = 'Search failed.';
			results = [];
		}
		searching = false;
	}

	function viewPlayer(id: number) {
		goto(`/players/${id}`);
	}
</script>

<main class="mx-auto max-w-4xl px-4 py-8">
	<h1 class="mb-2 text-3xl font-bold">Player Rankings</h1>
	<p class="mb-6 text-muted-foreground">Search for a player to see their Elo rating and stats.</p>

	<form class="join mb-8 w-full" on:submit|preventDefault={search}>
		<input
			type="text"
			class="input input-bordered join-item flex-1"
			placeholder="Search player by gamer tag..."
			bind:value={query}
		/>
		<button type="submit" class="btn btn-primary join-item" disabled={searching}>
			{searching ? 'Searching...' : 'Search'}
		</button>
	</form>

	{#if error}
		<p class="mb-4 text-error">{error}</p>
	{/if}

	{#if results.length > 0}
		<div class="overflow-x-auto">
			<table class="table table-zebra">
				<thead>
					<tr>
						<th>#</th>
						<th>Player</th>
						<th>Prefix</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					{#each results as player, i}
						<tr>
							<td class="font-bold text-muted-foreground">{i + 1}</td>
							<td class="font-semibold">{player.gamerTag}</td>
							<td class="text-muted-foreground">{player.prefix ?? '—'}</td>
							<td class="text-right">
								<button class="btn btn-ghost btn-sm" on:click={() => viewPlayer(player.id)}>
									View Stats
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}

	<div class="mt-12 rounded-lg border bg-base-200 p-6">
		<h2 class="mb-2 text-lg font-semibold">About Elo Ratings</h2>
		<p class="text-sm text-muted-foreground">
			Elo ratings are computed from a player's completed set history on start.gg. Ratings use
			K-factor 32 and start at 1500. They are updated chronologically and provide a rough skill
			estimate. Global rankings are not available because Elo is computed per-player from their own
			set data.
		</p>
	</div>
</main>
