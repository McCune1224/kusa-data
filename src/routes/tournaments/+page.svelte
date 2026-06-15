<script lang="ts">
	import { goto } from '$app/navigation';

	let query = '';
	let searching = false;
	let error = '';

	async function search() {
		const q = query.trim();
		if (!q) return;
		searching = true;
		error = '';
		try {
			const res = await fetch(`/api/tournaments?name=${encodeURIComponent(q)}`);
			if (!res.ok) {
				error =
					'Tournament search is not yet available. Try navigating directly to /tournaments/tournament-name.';
			}
		} catch {
			error = 'Search failed. Direct URL navigation is supported.';
		}
		searching = false;
	}

	function goToTournament() {
		const slug = query.trim().replace(/^https?:\/\/(www\.)?start\.gg\//, '');
		if (slug) goto(`/tournaments/${slug}`);
	}
</script>

<main class="mx-auto max-w-4xl px-4 py-8">
	<h1 class="mb-2 text-3xl font-bold">Tournaments</h1>
	<p class="mb-6 text-muted-foreground">
		Enter a tournament name or start.gg URL to view its Smash Ultimate roster.
	</p>

	<form class="join mb-8 w-full" on:submit|preventDefault={goToTournament}>
		<input
			type="text"
			class="input input-bordered join-item flex-1"
			placeholder="Tournament slug or URL (e.g. tech-chase-tuesday-63)"
			bind:value={query}
		/>
		<button type="submit" class="btn btn-primary join-item">Go</button>
	</form>

	{#if error}
		<p class="text-error">{error}</p>
	{/if}

	<div class="mt-12 rounded-lg border bg-base-200 p-6">
		<h2 class="mb-2 text-lg font-semibold">How to use</h2>
		<ul class="list-inside list-disc space-y-1 text-sm text-muted-foreground">
			<li>Paste a full start.gg URL or just the slug</li>
			<li>Example: <code class="rounded bg-base-300 px-1">tech-chase-tuesday-63</code></li>
			<li>Finds the Smash Ultimate singles event and lists all entrants</li>
		</ul>
	</div>
</main>
