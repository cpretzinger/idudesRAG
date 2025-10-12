/**
 * REDIS CACHING LAYER FOR <250MS RAG RESPONSES
 * 3-tier caching strategy optimized for 60+ concurrent users
 * Target: 60% cache hit rate, <$0.002 per search
 */

const Redis = require('redis');
const crypto = require('crypto');

class RAGCacheManager {
    constructor(redisUrl = process.env.REDIS_URL) {
        this.redis = Redis.createClient({ url: redisUrl });
        this.redis.on('error', (err) => console.error('Redis Client Error:', err));
        this.redis.connect();
        
        // Cache tiers with different TTLs
        this.CACHE_TIERS = {
            L1_QUERIES: {
                prefix: 'rag:query:',
                ttl: 300,        // 5 minutes - frequently accessed queries
                maxSize: 1000    // Top 1000 queries
            },
            L2_EMBEDDINGS: {
                prefix: 'rag:embed:',
                ttl: 3600,       // 1 hour - embedding cache
                maxSize: 5000    // 5000 embeddings
            },
            L3_RESULTS: {
                prefix: 'rag:result:',
                ttl: 1800,       // 30 minutes - search results
                maxSize: 2000    // 2000 result sets
            },
            ANALYTICS: {
                prefix: 'rag:analytics:',
                ttl: 86400,      // 24 hours - usage analytics
                maxSize: 10000   // Daily analytics
            }
        };
    }

    /**
     * L1 CACHE: QUERY-LEVEL CACHING
     * Caches complete search results for identical queries
     */
    async cacheSearchResults(queryText, contentTypes, filters, results, executionTimeMs) {
        const cacheKey = this.generateQueryCacheKey(queryText, contentTypes, filters);
        
        const cacheData = {
            queryText,
            contentTypes,
            filters,
            results,
            executionTimeMs,
            cachedAt: Date.now(),
            hitCount: 0
        };
        
        try {
            await this.redis.setEx(
                `${this.CACHE_TIERS.L1_QUERIES.prefix}${cacheKey}`,
                this.CACHE_TIERS.L1_QUERIES.ttl,
                JSON.stringify(cacheData)
            );
            
            // Track in LRU for cache size management
            await this.trackCacheEntry('L1_QUERIES', cacheKey);
            
            console.log(`[L1 Cache] Stored results for query: ${queryText.substring(0, 50)}...`);
        } catch (error) {
            console.error('[L1 Cache Error]:', error);
        }
    }

    async getCachedSearchResults(queryText, contentTypes, filters) {
        const cacheKey = this.generateQueryCacheKey(queryText, contentTypes, filters);
        
        try {
            const cached = await this.redis.get(`${this.CACHE_TIERS.L1_QUERIES.prefix}${cacheKey}`);
            
            if (cached) {
                const data = JSON.parse(cached);
                data.hitCount++;
                
                // Update hit count and extend TTL for popular queries
                await this.redis.setEx(
                    `${this.CACHE_TIERS.L1_QUERIES.prefix}${cacheKey}`,
                    this.CACHE_TIERS.L1_QUERIES.ttl,
                    JSON.stringify(data)
                );
                
                console.log(`[L1 Cache HIT] Query: ${queryText.substring(0, 50)}... (hits: ${data.hitCount})`);
                return data.results;
            }
            
            return null;
        } catch (error) {
            console.error('[L1 Cache Error]:', error);
            return null;
        }
    }

    /**
     * L2 CACHE: EMBEDDING CACHING
     * Caches embeddings for frequently searched text
     */
    async cacheEmbedding(text, embedding) {
        const textHash = this.generateTextHash(text);
        
        const embeddingData = {
            text: text.substring(0, 200), // Store snippet for debugging
            embedding,
            cachedAt: Date.now(),
            accessCount: 0
        };
        
        try {
            await this.redis.setEx(
                `${this.CACHE_TIERS.L2_EMBEDDINGS.prefix}${textHash}`,
                this.CACHE_TIERS.L2_EMBEDDINGS.ttl,
                JSON.stringify(embeddingData)
            );
            
            await this.trackCacheEntry('L2_EMBEDDINGS', textHash);
            
        } catch (error) {
            console.error('[L2 Cache Error]:', error);
        }
    }

    async getCachedEmbedding(text) {
        const textHash = this.generateTextHash(text);
        
        try {
            const cached = await this.redis.get(`${this.CACHE_TIERS.L2_EMBEDDINGS.prefix}${textHash}`);
            
            if (cached) {
                const data = JSON.parse(cached);
                data.accessCount++;
                
                // Update access count
                await this.redis.setEx(
                    `${this.CACHE_TIERS.L2_EMBEDDINGS.prefix}${textHash}`,
                    this.CACHE_TIERS.L2_EMBEDDINGS.ttl,
                    JSON.stringify(data)
                );
                
                console.log(`[L2 Cache HIT] Embedding for text hash: ${textHash.substring(0, 12)}...`);
                return data.embedding;
            }
            
            return null;
        } catch (error) {
            console.error('[L2 Cache Error]:', error);
            return null;
        }
    }

    /**
     * L3 CACHE: PARTIAL RESULTS CACHING
     * Caches intermediate search results by content type
     */
    async cachePartialResults(contentType, queryHash, results) {
        const cacheKey = `${contentType}:${queryHash}`;
        
        const partialData = {
            contentType,
            results,
            cachedAt: Date.now()
        };
        
        try {
            await this.redis.setEx(
                `${this.CACHE_TIERS.L3_RESULTS.prefix}${cacheKey}`,
                this.CACHE_TIERS.L3_RESULTS.ttl,
                JSON.stringify(partialData)
            );
            
            await this.trackCacheEntry('L3_RESULTS', cacheKey);
            
        } catch (error) {
            console.error('[L3 Cache Error]:', error);
        }
    }

    async getCachedPartialResults(contentType, queryHash) {
        const cacheKey = `${contentType}:${queryHash}`;
        
        try {
            const cached = await this.redis.get(`${this.CACHE_TIERS.L3_RESULTS.prefix}${cacheKey}`);
            
            if (cached) {
                const data = JSON.parse(cached);
                console.log(`[L3 Cache HIT] Partial results for ${contentType}`);
                return data.results;
            }
            
            return null;
        } catch (error) {
            console.error('[L3 Cache Error]:', error);
            return null;
        }
    }

    /**
     * INTELLIGENT CACHE WARMING
     * Pre-populate cache with popular content
     */
    async warmCache(popularQueries, popularEmbeddings) {
        console.log('[Cache Warming] Starting cache warm-up...');
        
        // Warm L1 with popular queries (run these searches)
        for (const query of popularQueries) {
            // This would trigger actual searches to populate cache
            console.log(`[Cache Warming] Preparing query: ${query.text}`);
        }
        
        // Warm L2 with popular embeddings
        for (const embedding of popularEmbeddings) {
            await this.cacheEmbedding(embedding.text, embedding.vector);
        }
        
        console.log('[Cache Warming] Cache warm-up completed');
    }

    /**
     * CACHE ANALYTICS AND OPTIMIZATION
     */
    async trackCachePerformance(operation, cacheHit, executionTimeMs) {
        const today = new Date().toISOString().split('T')[0];
        const analyticsKey = `${this.CACHE_TIERS.ANALYTICS.prefix}${today}`;
        
        const increment = cacheHit ? 1 : 0;
        
        await Promise.all([
            this.redis.hIncrBy(analyticsKey, 'total_requests', 1),
            this.redis.hIncrBy(analyticsKey, 'cache_hits', increment),
            this.redis.hIncrBy(analyticsKey, 'total_time_ms', executionTimeMs),
            this.redis.expire(analyticsKey, this.CACHE_TIERS.ANALYTICS.ttl)
        ]);
    }

    async getCacheAnalytics(days = 7) {
        const analytics = [];
        
        for (let i = 0; i < days; i++) {
            const date = new Date();
            date.setDate(date.getDate() - i);
            const dateStr = date.toISOString().split('T')[0];
            
            const analyticsKey = `${this.CACHE_TIERS.ANALYTICS.prefix}${dateStr}`;
            const data = await this.redis.hGetAll(analyticsKey);
            
            if (Object.keys(data).length > 0) {
                const totalRequests = parseInt(data.total_requests) || 0;
                const cacheHits = parseInt(data.cache_hits) || 0;
                const totalTime = parseInt(data.total_time_ms) || 0;
                
                analytics.push({
                    date: dateStr,
                    totalRequests,
                    cacheHits,
                    hitRate: totalRequests > 0 ? (cacheHits / totalRequests) : 0,
                    avgResponseTime: totalRequests > 0 ? (totalTime / totalRequests) : 0
                });
            }
        }
        
        return analytics;
    }

    /**
     * CACHE SIZE MANAGEMENT (LRU-style)
     */
    async trackCacheEntry(tier, key) {
        const trackerKey = `${this.CACHE_TIERS[tier].prefix}tracker`;
        const now = Date.now();
        
        // Add to sorted set with timestamp as score
        await this.redis.zAdd(trackerKey, { score: now, value: key });
        
        // Trim to max size
        const count = await this.redis.zCard(trackerKey);
        if (count > this.CACHE_TIERS[tier].maxSize) {
            // Get oldest entries to remove
            const toRemove = await this.redis.zRange(trackerKey, 0, count - this.CACHE_TIERS[tier].maxSize - 1);
            
            // Remove from cache and tracker
            for (const oldKey of toRemove) {
                await this.redis.del(`${this.CACHE_TIERS[tier].prefix}${oldKey}`);
            }
            await this.redis.zRemRangeByRank(trackerKey, 0, count - this.CACHE_TIERS[tier].maxSize - 1);
        }
    }

    /**
     * SMART CACHE INVALIDATION
     */
    async invalidateContentCache(contentType, contentId) {
        const pattern = `${this.CACHE_TIERS.L3_RESULTS.prefix}${contentType}:*`;
        
        try {
            const keys = await this.redis.keys(pattern);
            if (keys.length > 0) {
                await this.redis.del(keys);
                console.log(`[Cache Invalidation] Cleared ${keys.length} ${contentType} cache entries`);
            }
        } catch (error) {
            console.error('[Cache Invalidation Error]:', error);
        }
    }

    async invalidateAllCache() {
        const patterns = [
            `${this.CACHE_TIERS.L1_QUERIES.prefix}*`,
            `${this.CACHE_TIERS.L2_EMBEDDINGS.prefix}*`,
            `${this.CACHE_TIERS.L3_RESULTS.prefix}*`
        ];
        
        for (const pattern of patterns) {
            const keys = await this.redis.keys(pattern);
            if (keys.length > 0) {
                await this.redis.del(keys);
            }
        }
        
        console.log('[Cache Invalidation] All caches cleared');
    }

    /**
     * CACHE KEY GENERATION
     */
    generateQueryCacheKey(queryText, contentTypes, filters) {
        const queryData = {
            text: queryText.toLowerCase().trim(),
            types: Array.isArray(contentTypes) ? contentTypes.sort() : [],
            filters: this.normalizeFilters(filters)
        };
        
        return crypto.createHash('md5').update(JSON.stringify(queryData)).digest('hex');
    }

    generateTextHash(text) {
        return crypto.createHash('md5').update(text.trim().toLowerCase()).digest('hex');
    }

    normalizeFilters(filters) {
        if (!filters || typeof filters !== 'object') return {};
        
        // Sort and normalize filter object
        const normalized = {};
        Object.keys(filters).sort().forEach(key => {
            normalized[key] = filters[key];
        });
        
        return normalized;
    }

    /**
     * HEALTH CHECK AND MONITORING
     */
    async getHealthStatus() {
        try {
            const ping = await this.redis.ping();
            const info = await this.redis.info('memory');
            
            // Parse memory usage
            const memoryLines = info.split('\r\n');
            const usedMemory = memoryLines.find(line => line.startsWith('used_memory:'));
            const maxMemory = memoryLines.find(line => line.startsWith('maxmemory:'));
            
            return {
                status: 'healthy',
                ping: ping === 'PONG',
                memory: {
                    used: usedMemory ? usedMemory.split(':')[1] : 'unknown',
                    max: maxMemory ? maxMemory.split(':')[1] : 'unknown'
                },
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            return {
                status: 'unhealthy',
                error: error.message,
                timestamp: new Date().toISOString()
            };
        }
    }

    async close() {
        await this.redis.quit();
    }
}

/**
 * RAG SEARCH WITH INTEGRATED CACHING
 * This function demonstrates how to use the cache in a complete search flow
 */
class CachedRAGSearcher {
    constructor(cacheManager, dbConnection) {
        this.cache = cacheManager;
        this.db = dbConnection;
    }

    async search(queryText, contentTypes = [], filters = {}, limit = 20) {
        const startTime = Date.now();
        let cacheHit = false;
        
        try {
            // Try L1 cache first (complete results)
            const cachedResults = await this.cache.getCachedSearchResults(queryText, contentTypes, filters);
            if (cachedResults) {
                cacheHit = true;
                await this.cache.trackCachePerformance('search', true, Date.now() - startTime);
                return {
                    results: cachedResults,
                    executionTime: Date.now() - startTime,
                    cacheHit: true,
                    source: 'L1_cache'
                };
            }

            // Try L2 cache for embeddings
            let queryEmbedding = await this.cache.getCachedEmbedding(queryText);
            if (!queryEmbedding) {
                // Generate embedding (expensive operation)
                queryEmbedding = await this.generateEmbedding(queryText);
                await this.cache.cacheEmbedding(queryText, queryEmbedding);
            }

            // Execute hybrid search with partial caching
            const results = await this.executeHybridSearch(queryText, queryEmbedding, contentTypes, filters, limit);
            
            // Cache the complete results
            const executionTime = Date.now() - startTime;
            await this.cache.cacheSearchResults(queryText, contentTypes, filters, results, executionTime);
            await this.cache.trackCachePerformance('search', false, executionTime);

            return {
                results,
                executionTime,
                cacheHit: false,
                source: 'database'
            };

        } catch (error) {
            console.error('[Cached RAG Search Error]:', error);
            throw error;
        }
    }

    async generateEmbedding(text) {
        // Placeholder - in production, call OpenAI API
        // const embedding = await openai.embeddings.create({
        //     model: "text-embedding-3-small",
        //     input: text
        // });
        // return embedding.data[0].embedding;
        
        // For now, return mock embedding
        return new Array(1536).fill(0).map(() => Math.random());
    }

    async executeHybridSearch(queryText, embedding, contentTypes, filters, limit) {
        // Call the PostgreSQL hybrid search function
        const query = `
            SELECT * FROM core.hybrid_search($1, $2, $3, 0.7, true)
        `;
        
        const result = await this.db.query(query, [queryText, contentTypes, limit]);
        return result.rows;
    }
}

module.exports = { RAGCacheManager, CachedRAGSearcher };

// Usage in n8n:
// const { RAGCacheManager } = require('./redis-cache-layer.js');
// const cacheManager = new RAGCacheManager(process.env.REDIS_URL);
// const results = await cacheManager.getCachedSearchResults(query, types, filters);