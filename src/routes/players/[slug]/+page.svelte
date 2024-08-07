<script lang="ts">
	import type { PageServerData } from './$types';
	export let data: PageServerData;
	const player = data.playerResponse.player;
	console.log(player);
</script>

<main>
	{#if player}
		<p>{player.gamerTag} - {player.id}</p>
	{:else}
		<h1 class="text-7xl">Player not found with id {data.slug}</h1>
	{/if}
</main>
