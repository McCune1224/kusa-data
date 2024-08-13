//ioredis use:
import Redis from 'ioredis';
import { REDIS_URL } from '$env/static/private';

//TODO: Find a better measurement for TTL
const DEFAULT_TTL = 60 * 5000; // 5 minutes
const redisClient = new Redis(REDIS_URL);

// wrapper for redisClient.set with JSON.stringify and a default TTL of 5 minutes
export function jsonSet(key: string, value: any, ttl: number = DEFAULT_TTL) {
	return redisClient.set(key, JSON.stringify(value), 'EX', ttl);
}

export default redisClient;
