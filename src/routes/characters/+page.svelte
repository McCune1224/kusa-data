<script lang="ts">
	import { goto } from '$app/navigation';

	let query = '';
	let searching = false;

	async function searchByCharacter() {
		const q = query.trim();
		if (!q) return;
		searching = true;
		goto(`/?q=${encodeURIComponent(q)}`);
	}

	const popularCharacters = [
		'Mr. Game & Watch',
		'R.O.B.',
		'Pyra',
		'Mythra',
		'Sora',
		'Steve',
		'Aegis',
		'Joker',
		'Palutena',
		'Roy',
		'Chrom',
		'Wolf',
		'Fox',
		'Pikachu',
		'ZSS',
		'Peach',
		'Daisy',
		'Cloud',
		'Ken',
		'Ryu',
		'Terry',
		'Kazuya',
		'Min Min',
		'Snake',
		'Sonic',
		'Mario',
		'Luigi',
		'Donkey Kong',
		'Bowser',
		'Yoshi'
	];
</script>

<main class="mx-auto max-w-4xl px-4 py-8">
	<h1 class="mb-2 text-3xl font-bold">Character Browser</h1>
	<p class="mb-6 text-muted-foreground">
		Character stats are displayed per-player on their profile page. Use the player search to find
		character usage data.
	</p>

	<form class="join mb-8 w-full" on:submit|preventDefault={searchByCharacter}>
		<input
			type="text"
			class="input input-bordered join-item flex-1"
			placeholder="Search for a player to see character stats..."
			bind:value={query}
		/>
		<button type="submit" class="btn btn-primary join-item" disabled={searching}>
			Search Player
		</button>
	</form>

	<h2 class="mb-3 text-lg font-semibold">Smash Ultimate Roster</h2>
	<div class="flex flex-wrap gap-2">
		{#each popularCharacters as char}
			<a href="/?q={char}" class="badge badge-outline badge-lg hover:badge-primary">
				{char}
			</a>
		{/each}
	</div>
</main>
