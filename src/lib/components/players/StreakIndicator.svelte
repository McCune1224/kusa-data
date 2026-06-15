<script lang="ts">
	export let type: 'win' | 'loss' | null = null;
	export let count: number = 0;

	$: isHot = type === 'win' && count >= 3;
	$: isCold = type === 'loss' && count >= 3;
	$: badgeClass = type === 'win' ? 'badge-success' : 'badge-error';
	$: label = type === 'win' ? `${count}-win streak` : `${count}-loss streak`;
</script>

{#if type}
	<span class="badge {badgeClass} badge-lg gap-1">
		{label}
	</span>
{:else}
	<span class="badge badge-ghost badge-lg">—</span>
{/if}
