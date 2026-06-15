<script lang="ts">
	import { onMount } from 'svelte';

	export let playerId: number;

	let sets: any[] = [];
	let loading = true;
	let page = 1;
	let totalPages = 1;
	let total = 0;

	onMount(() => loadPage(1));

	async function loadPage(p: number) {
		loading = true;
		page = p;
		try {
			const res = await fetch(`/api/players/${playerId}/sets?page=${p}&perPage=25`);
			const data = await res.json();
			sets = data.nodes ?? [];
			totalPages = data.pageInfo?.totalPages ?? 1;
			total = data.pageInfo?.total ?? 0;
		} catch {
			sets = [];
		}
		loading = false;
	}

	function roundLabel(set: any): string {
		return set.fullRoundText ?? `Round ${set.id}`;
	}

	function scoreDisplay(set: any): string {
		return (
			set.displayScore ??
			`${set.slots?.[0]?.standing?.stats?.score?.value ?? '?'} - ${set.slots?.[1]?.standing?.stats?.score?.value ?? '?'}`
		);
	}
</script>

<div class="card border bg-base-200">
	<div class="card-body">
		<h2 class="card-title">
			Set History
			{#if total > 0}
				<span class="text-sm font-normal text-muted-foreground">({total} total)</span>
			{/if}
		</h2>

		{#if loading}
			<div class="flex justify-center py-8">
				<span class="loading loading-spinner loading-lg"></span>
			</div>
		{:else if sets.length === 0}
			<p class="py-4 text-center text-muted-foreground">No sets found.</p>
		{:else}
			<div class="overflow-x-auto">
				<table class="table table-zebra table-sm">
					<thead>
						<tr>
							<th>Round</th>
							<th>Score</th>
							<th>Event</th>
						</tr>
					</thead>
					<tbody>
						{#each sets as set}
							<tr>
								<td class="font-medium">{roundLabel(set)}</td>
								<td>{scoreDisplay(set)}</td>
								<td class="text-muted-foreground">{set.event?.name ?? '—'}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			{#if totalPages > 1}
				<div class="join mt-4 flex justify-center">
					<button
						class="join-item btn btn-sm"
						disabled={page <= 1}
						on:click={() => loadPage(page - 1)}
					>
						«
					</button>
					<span class="join-item btn btn-sm btn-disabled">
						Page {page} of {totalPages}
					</span>
					<button
						class="join-item btn btn-sm"
						disabled={page >= totalPages}
						on:click={() => loadPage(page + 1)}
					>
						»
					</button>
				</div>
			{/if}
		{/if}
	</div>
</div>
