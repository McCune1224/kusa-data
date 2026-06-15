<script lang="ts">
	import { page } from '$app/stores';
	import { building } from '$app/environment';
</script>

<div class="flex min-h-[60vh] items-center justify-center px-4">
	<div class="text-center">
		<h1 class="text-6xl font-bold text-primary">{$page.status}</h1>
		<p class="mt-2 text-lg text-muted-foreground">
			{$page.status === 404 ? 'Page not found' : 'Something went wrong'}
		</p>
		<a href="/" class="btn btn-primary mt-6">Back to Home</a>
	</div>
</div>
