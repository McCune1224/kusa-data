<script lang="ts">
	import { onMount } from 'svelte';
	import type { PageServerData } from './$types';

	export let data: PageServerData;

	const player = data.player;
	const opponent = data.opponent;

	let playerSets: any[] = [];
	let loading = true;
	let record = { wins: 0, losses: 0 };
	let recentSets: any[] = [];

	onMount(async () => {
		if (!player || !opponent) {
			loading = false;
			return;
		}

		try {
			// Fetch both players' sets and find mutual matches
			const [pRes, oRes] = await Promise.all([
				fetch(`/api/players/${player.id}/sets?perPage=50`),
				fetch(`/api/players/${opponent.id}/sets?perPage=50`)
			]);
			const pData = await pRes.json();
			const oData = await oRes.json();

			const pSets = (pData.nodes ?? []) as any[];
			const oSets = (oData.nodes ?? []) as any[];

			// Find sets where both players participated (match by set ID)
			const pSetIds = new Set(pSets.map((s: any) => s.id));
			const common = oSets.filter((s: any) => pSetIds.has(s.id));

			// Deduplicate and sort by completedAt
			const seen = new Set<number>();
			for (const set of common) {
				if (!seen.has(set.id)) {
					seen.add(set.id);
					recentSets.push(set);
				}
			}
			recentSets.sort(
				(a, b) => new Date(b.completedAt ?? 0).getTime() - new Date(a.completedAt ?? 0).getTime()
			);

			// Compute W/L: find which slot is the player, which is opponent
			for (const set of recentSets) {
				const pSlot = set.slots?.find(
					(s: any) =>
						s.entrant?.id === player?.id ||
						s.entrant?.name?.toLowerCase().includes(player.gamerTag.toLowerCase())
				);
				const oSlot = set.slots?.find(
					(s: any) =>
						s.entrant?.id === opponent?.id ||
						s.entrant?.name?.toLowerCase().includes(opponent.gamerTag.toLowerCase())
				);
				if (
					pSlot?.standing?.stats?.score?.value != null &&
					oSlot?.standing?.stats?.score?.value != null
				) {
					if (pSlot.standing.stats.score.value > oSlot.standing.stats.score.value) {
						record.wins++;
					} else {
						record.losses++;
					}
				}
			}
		} catch {
			// ignore
		}
		loading = false;
	});

	function scoreDisplay(set: any): string {
		return set.displayScore ?? '?';
	}
</script>

<main class="mx-auto max-w-4xl px-4 py-8">
	{#if !player || !opponent}
		<h1 class="text-2xl font-bold">Player not found</h1>
		<a href="/" class="btn btn-primary mt-4">Back to Home</a>
	{:else}
		<h1 class="mb-6 text-3xl font-bold">
			Head-to-Head:
			<a href="/players/{player.id}" class="link link-primary">{player.gamerTag}</a>
			vs
			<a href="/players/{opponent.id}" class="link link-primary">{opponent.gamerTag}</a>
		</h1>

		{#if loading}
			<div class="flex justify-center py-12">
				<span class="loading loading-spinner loading-lg"></span>
			</div>
		{:else}
			<div class="stats mb-8 w-full shadow">
				<div class="stat">
					<div class="stat-title">{player.gamerTag}</div>
					<div class="stat-value text-success">{record.wins}</div>
					<div class="stat-desc">wins</div>
				</div>
				<div class="stat">
					<div class="stat-title">Record</div>
					<div class="stat-value">
						{record.wins}-{record.losses}
					</div>
					<div class="stat-desc">
						{record.wins + record.losses > 0
							? `${Math.round((record.wins / (record.wins + record.losses)) * 100)}%`
							: 'No sets'}
					</div>
				</div>
				<div class="stat">
					<div class="stat-title">{opponent.gamerTag}</div>
					<div class="stat-value text-error">{record.losses}</div>
					<div class="stat-desc">wins</div>
				</div>
			</div>

			{#if recentSets.length === 0}
				<p class="py-8 text-center text-muted-foreground">
					No mutual sets found between these players.
				</p>
			{:else}
				<h2 class="mb-3 text-xl font-semibold">Recent Sets</h2>
				<div class="overflow-x-auto">
					<table class="table table-zebra">
						<thead>
							<tr>
								<th>Date</th>
								<th>Round</th>
								<th>Score</th>
								<th>Event</th>
							</tr>
						</thead>
						<tbody>
							{#each recentSets as set}
								<tr>
									<td class="text-sm text-muted-foreground">
										{set.completedAt ? new Date(set.completedAt).toLocaleDateString() : '—'}
									</td>
									<td>{set.fullRoundText ?? '—'}</td>
									<td class="font-mono font-semibold">{scoreDisplay(set)}</td>
									<td class="text-muted-foreground">{set.event?.name ?? '—'}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		{/if}
	{/if}
</main>
