<script lang="ts">
	import type { PageData } from './$types';
	export let data: PageData;
	const tournamentSlug = data.params.slug;
</script>

<main class="flex items-center justify-center bg-background px-4 py-12 sm:px-6 lg:px-8">
	<div class="flex flex-col">
		<h1>{tournamentSlug}</h1>
		<p>todo...</p>
	</div>
</main>
