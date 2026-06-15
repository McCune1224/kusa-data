<script lang="ts">
	import { goto } from '$app/navigation';
	import ParticipantCount from './ParticipantCount.svelte';

	let playerQuery = '';
	let searching = false;
	let results: { id: number; gamerTag: string; prefix: string | null; image: string | null }[] = [];
	let noResults = false;

	async function searchPlayer() {
		const q = playerQuery.trim();
		if (!q) return;
		searching = true;
		noResults = false;
		try {
			const res = await fetch(`/api/players?name=${encodeURIComponent(q)}`);
			const data = await res.json();
			results = data.players ?? [];
			noResults = results.length === 0;
		} catch {
			results = [];
			noResults = true;
		}
		searching = false;
	}

	function goToPlayer(id: number) {
		goto(`/players/${id}`);
	}
</script>

<main
	class="flex min-h-[100dvh] items-center justify-center bg-background px-4 py-12 sm:px-6 lg:px-8"
>
	<div class="mx-auto flex w-full max-w-2xl flex-col gap-12 text-center">
		<div>
			<h1 class="text-4xl font-bold tracking-tight text-foreground sm:text-6xl">Kusa Data</h1>
			<p class="mt-4 text-lg text-muted-foreground">
				Look up Smash Ultimate tournament data from
				<a href="https://start.gg" class="link link-primary hover:underline">start.gg</a>.
			</p>
		</div>

		<div class="card border bg-base-200 p-6">
			<h2 class="mb-4 text-xl font-semibold">Search for a Player</h2>
			<form class="join w-full" on:submit|preventDefault={searchPlayer}>
				<input
					type="text"
					class="input input-bordered join-item w-full"
					placeholder="Enter gamer tag (e.g. Sparg0, MkLeo)"
					bind:value={playerQuery}
				/>
				<button type="submit" class="btn btn-primary join-item" disabled={searching}>
					{searching ? 'Searching...' : 'Search'}
				</button>
			</form>

			{#if noResults}
				<p class="mt-4 text-muted-foreground">No players found. Try a different name.</p>
			{/if}

			{#if results.length > 0}
				<ul class="mt-4 divide-y">
					{#each results as player}
						<li>
							<button
								class="btn btn-ghost w-full justify-start gap-3 text-left"
								on:click={() => goToPlayer(player.id)}
							>
								{#if player.image}
									<img src={player.image} alt="" class="h-8 w-8 rounded-full" />
								{/if}
								<div>
									<span class="font-semibold">{player.gamerTag}</span>
									{#if player.prefix}
										<span class="ml-2 text-sm text-muted-foreground">| {player.prefix}</span>
									{/if}
								</div>
							</button>
						</li>
					{/each}
				</ul>
			{/if}
		</div>

		<div class="card border bg-base-200 p-6">
			<h2 class="mb-4 text-xl font-semibold">Find a Tournament</h2>
			<ParticipantCount />
		</div>

		<footer class="flex flex-col items-center gap-2 text-sm text-muted-foreground">
			<div>
				Made with <span class="text-primary"> ☕</span> by Kusa (Alex McCune)
			</div>
			<div class="flex items-center gap-4">
				<a target="_blank" href="https://twitter.com/KusaAlexM" class="hover:underline">
					Twitter
				</a>
				<a target="_blank" href="https://github.com/mcCune1224" class="hover:underline"> Github </a>
			</div>
		</footer>
	</div>
</main>
