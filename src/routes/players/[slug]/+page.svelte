<script lang="ts">
	import { onMount } from 'svelte';
	import type { PageServerData } from './$types';

	import PlayerHeader from '$lib/components/players/PlayerHeader.svelte';
	import StatsSummary from '$lib/components/players/StatsSummary.svelte';
	import StreakIndicator from '$lib/components/players/StreakIndicator.svelte';
	import CharacterBreakdown from '$lib/components/players/CharacterBreakdown.svelte';
	import StageBreakdown from '$lib/components/players/StageBreakdown.svelte';
	import TopPlacements from '$lib/components/players/TopPlacements.svelte';
	import PlacementTimeline from '$lib/components/players/PlacementTimeline.svelte';
	import SetHistory from '$lib/components/players/SetHistory.svelte';
	import RecentTournaments from '$lib/components/players/RecentTournaments.svelte';
	import HeadToHead from '$lib/components/players/HeadToHead.svelte';

	export let data: PageServerData;

	const user = data.playerResponse?.user ?? null;
	const playerId = user ? user.player.id : 0;
	const gamerTag = user?.player?.gamerTag ?? '';

	// Stats loaded client-side from the API
	let stats: any = null;
	let statsLoading = true;

	// Tournament data from server
	let tournaments: any[] = [];
	let placements: { placement: number; tournamentName: string; numEntrants: number | null }[] = [];
	let totalEvents = 0;

	$: if (data.tournamentHistory?.user?.tournaments?.nodes) {
		const allTournaments = data.tournamentHistory.user.tournaments.nodes
			.filter((t: any) => t.events.length > 0)
			.sort((a: any, b: any) => b.id - a.id);
		tournaments = allTournaments;

		const allPlacements: {
			placement: number;
			tournamentName: string;
			numEntrants: number | null;
		}[] = [];
		for (const t of allTournaments) {
			for (const e of t.events) {
				const p = e.entrants?.nodes?.[0]?.standing?.placement;
				if (p != null) {
					allPlacements.push({
						placement: p,
						tournamentName: `${t.name} — ${e.name}`,
						numEntrants: e.numEntrants
					});
					totalEvents++;
				}
			}
		}
		placements = allPlacements;
	}

	function pickImage(): string | null {
		const imgs = data.tournamentHistory?.user?.images;
		if (!imgs || imgs.length === 0) return null;
		if (imgs.length === 2) return imgs[1].url;
		return imgs[0].url;
	}

	function avgPlacement(): number {
		if (placements.length === 0) return 0;
		return placements.reduce((s, p) => s + p.placement, 0) / placements.length;
	}

	onMount(async () => {
		if (!playerId) return;
		try {
			const res = await fetch(`/api/players/${playerId}/stats`);
			stats = await res.json();
		} catch {
			stats = null;
		}
		statsLoading = false;
	});
</script>

<main class="mx-auto max-w-6xl px-4 py-6">
	{#if user}
		<!-- Header -->
		<div class="mb-6">
			<PlayerHeader
				{gamerTag}
				imageUrl={pickImage()}
				name={data.tournamentHistory?.user?.name ?? null}
			/>
		</div>

		<!-- Streak badge -->
		<div class="mb-4 flex items-center gap-2">
			{#if statsLoading}
				<span class="loading loading-spinner loading-sm"></span>
			{:else if stats}
				<StreakIndicator type={stats.streak?.type} count={stats.streak?.count} />
				<span class="text-sm text-muted-foreground">
					Best streak: {stats.bestWinStreak} wins
				</span>
			{/if}
		</div>

		<!-- Summary Stats -->
		<div class="mb-6">
			<StatsSummary
				wins={stats?.winLoss?.wins ?? 0}
				losses={stats?.winLoss?.losses ?? 0}
				winRate={stats?.winLoss?.winRate ?? 0}
				setCount={stats?.setCount ?? 0}
				tournamentCount={totalEvents}
				bestStreak={stats?.bestWinStreak ?? 0}
				avgPlacement={avgPlacement()}
			/>
		</div>

		<!-- Middle row: Characters, Stages, Top Placements -->
		<div class="mb-6 grid grid-cols-1 gap-4 md:grid-cols-3">
			<CharacterBreakdown
				characters={stats?.characters?.characters ?? []}
				totalGames={stats?.characters?.totalGames ?? 0}
			/>
			<StageBreakdown
				stages={stats?.stages?.stages ?? []}
				totalGames={stats?.stages?.totalGames ?? 0}
			/>
			<TopPlacements {placements} />
		</div>

		<!-- Placement Timeline -->
		<div class="mb-6">
			<PlacementTimeline {placements} />
		</div>

		<!-- Set History (client-loaded) -->
		<div class="mb-6">
			<SetHistory {playerId} />
		</div>

		<!-- Head-to-Head -->
		<div class="mb-6">
			<HeadToHead />
		</div>

		<!-- Recent Tournaments (server-loaded) -->
		<div class="mb-6">
			<RecentTournaments {tournaments} />
		</div>
	{:else}
		<div class="flex min-h-[50vh] items-center justify-center">
			<div class="text-center">
				<h1 class="text-4xl font-bold">Player Not Found</h1>
				<p class="mt-2 text-muted-foreground">
					No player found with
					<strong>{data.slug}</strong>.
				</p>
				<a href="/" class="btn btn-primary mt-4">Back to Home</a>
			</div>
		</div>
	{/if}
</main>
