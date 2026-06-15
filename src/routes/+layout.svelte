<script>
	import '../app.css';
</script>

<navbar class="navbar bg-info text-info-content">
	<div class="flex-1">
		<a href="/" class="btn btn-ghost text-xl">Kusa Data</a>
	</div>
	<div class="flex-none gap-1">
		<a href="/rankings" class="btn btn-ghost btn-sm">Rankings</a>
		<a href="/characters" class="btn btn-ghost btn-sm">Characters</a>
		<a href="/tournaments" class="btn btn-ghost btn-sm">Tournaments</a>
	</div>
</navbar>

<slot />
