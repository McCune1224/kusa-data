<script lang="ts">
	import type { Participant } from '$lib/startql/result_types';

	export let player: Participant;
</script>

<a target="_blank" href="#" class="border-4 hover:border-info">
	<div class="stat shadow">
		{#if player.user.genderPronoun}
			<div class="stat-title">{player.user.genderPronoun}</div>
		{:else}
			<div class="stat-title">?</div>
		{/if}
		<div class="stat-value">{player.gamerTag}</div>
	</div>
</a>
