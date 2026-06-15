<script lang="ts">
	export let gamerTag: string;
	export let prefix: string | null = null;
	export let imageUrl: string | null = null;
	export let name: string | null = null;
</script>

<div class="card border bg-base-200">
	<div class="card-body flex-row items-center gap-6">
		{#if imageUrl}
			<div class="avatar">
				<div class="w-20 rounded-full ring ring-primary ring-offset-2 ring-offset-base-200">
					<img src={imageUrl} alt="{gamerTag} avatar" />
				</div>
			</div>
		{:else}
			<div
				class="flex h-20 w-20 items-center justify-center rounded-full bg-primary text-3xl font-bold text-primary-content"
			>
				{gamerTag.charAt(0).toUpperCase()}
			</div>
		{/if}
		<div>
			<h1 class="text-3xl font-bold">
				{#if prefix}
					<span class="text-lg text-muted-foreground">{prefix}</span>
					{' '}
				{/if}
				{gamerTag}
			</h1>
			{#if name}
				<p class="text-muted-foreground">{name}</p>
			{/if}
		</div>
	</div>
</div>
