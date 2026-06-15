<script lang="ts">
	export let wins: number = 0;
	export let losses: number = 0;
	export let winRate: number = 0;
	export let setCount: number = 0;
	export let tournamentCount: number = 0;
	export let bestStreak: number = 0;
	export let avgPlacement: number = 0;

	$: winRateDisplay = winRate.toFixed(1);
	$: avgPlacementDisplay = avgPlacement > 0 ? avgPlacement.toFixed(1) : '—';
</script>

<div class="stats stats-vertical w-full shadow lg:stats-horizontal">
	<div class="stat">
		<div class="stat-title">W/L</div>
		<div class="stat-value">
			{wins}<span class="text-base text-muted-foreground">-{losses}</span>
		</div>
		<div class="stat-desc">{winRateDisplay}% win rate</div>
	</div>

	<div class="stat">
		<div class="stat-title">Sets Played</div>
		<div class="stat-value">{setCount}</div>
		<div class="stat-desc">{tournamentCount} tournaments</div>
	</div>

	<div class="stat">
		<div class="stat-title">Best Streak</div>
		<div class="stat-value">{bestStreak}</div>
		<div class="stat-desc">consecutive wins</div>
	</div>

	<div class="stat">
		<div class="stat-title">Avg Placement</div>
		<div class="stat-value">{avgPlacementDisplay}</div>
		<div class="stat-desc">across all events</div>
	</div>
</div>
