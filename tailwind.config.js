/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {}
	},
	plugins: [require('daisyui'), 'prettier-plugin-tailwindcss'],
	daisyui: {
		themes: ['lemonade']
	}
};
