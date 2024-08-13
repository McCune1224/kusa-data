import { createClient } from 'redis';

const client = createClient({
  url: 'redis://localhost:6379', // Change this to your Redis server URL
});

client.on('error', (err) => console.error('Redis Client Error', err));

(async () => {
  await client.connect();
})();

export default client;