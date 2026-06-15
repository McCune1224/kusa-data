import Redis from 'ioredis';
import { REDIS_URL } from '$env/static/private';

// TTL values in milliseconds
const DEFAULT_TTL = 60 * 5000; // 5 minutes
const SETS_TTL = 60 * 1000 * 30; // 30 minutes (sets don't change often)
const STATS_TTL = 60 * 1000 * 15; // 15 minutes (computed stats)

const redisClient = new Redis(REDIS_URL);

/**
 * Wrapper for redisClient.set with JSON.stringify and configurable TTL.
 */
export function jsonSet(key: string, value: any, ttl: number = DEFAULT_TTL) {
	return redisClient.set(key, JSON.stringify(value), 'EX', ttl);
}

/**
 * Cache-first data fetcher: checks Redis, falls back to fetchFn, stores result.
 * Returns `{ data, cached }` where `cached` indicates if data came from cache.
 */
export async function cacheFirst<T>(
	key: string,
	fetchFn: () => Promise<T>,
	ttl: number = DEFAULT_TTL
): Promise<{ data: T; cached: boolean }> {
	try {
		const cached = await redisClient.get(key);
		if (cached) {
			return { data: JSON.parse(cached) as T, cached: true };
		}
	} catch {
		// Redis unavailable, fall through to fetchFn
	}

	const data = await fetchFn();

	try {
		await jsonSet(key, data, ttl);
	} catch {
		// Cache write failure is non-fatal
	}

	return { data, cached: false };
}

export { SETS_TTL, STATS_TTL };
export default redisClient;
