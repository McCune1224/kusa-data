<script lang="ts">
	import ParticipantCount from './ParticipantCount.svelte';
</script>

<main
	class="flex min-h-[100dvh] items-center justify-center bg-background px-4 py-12 sm:px-6 lg:px-8"
>
	<div class="mx-auto max-w-2xl text-center">
		<h1 class="text-4xl font-bold tracking-tight text-foreground sm:text-6xl">Kusa Data</h1>
		<p class="mt-4 text-lg text-muted-foreground">
			Type a tournament name or provide a tournament
			<a href="https://start.gg" class="hover:underline link link-primary">start.gg</a> URL to get started
		</p>
		<ParticipantCount />
		<footer class="text-sm mt-12 flex flex-col items-center gap-2 text-muted-foreground">
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
