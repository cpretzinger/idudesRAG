#!/usr/bin/env node

/**
 * n8n Workflow Auto-Sync Daemon
 *
 * Listens to PostgreSQL notifications and automatically syncs workflows
 * to local JSON files when they're updated in n8n UI.
 *
 * Usage:
 *   node sync-daemon.js
 *   or
 *   pnpm run daemon
 */

const { Client } = require('pg');
const { exec } = require('child_process');
const util = require('util');
const fs = require('fs').promises;
const path = require('path');

const execPromise = util.promisify(exec);

// Configuration
const DB_CONFIG = {
    host: process.env.POSTGRES_HOST || 'ai-postgres',
    port: process.env.POSTGRES_PORT || 5432,
    user: process.env.POSTGRES_USER || 'ai_user',
    password: process.env.POSTGRES_PASSWORD || 'PtLIu0SN9oJWEvMVxxe5rCGym',
    database: process.env.POSTGRES_DB || 'ai_assistant'
};

const CHANNEL = 'workflow_updates';
const DEBOUNCE_MS = 2000; // Wait 2 seconds before syncing
const LOG_FILE = path.join(__dirname, 'sync-daemon.log');

// Detect Docker environment
const IS_DOCKER = fs.existsSync('/.dockerenv');
const SYNC_SCRIPT = IS_DOCKER
    ? '/app/scripts/sync-n8n-workflow.sh'
    : path.join(__dirname, '../sync-n8n-workflow.sh');

// State
let pendingSyncs = new Map(); // workflow_id -> timeout
let syncHistory = [];
const MAX_HISTORY = 50;

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    red: '\x1b[31m'
};

// Logging utility
async function log(level, message, data = null) {
    const timestamp = new Date().toISOString();
    const logEntry = {
        timestamp,
        level,
        message,
        data
    };

    // Console output with colors
    const levelColors = {
        INFO: colors.blue,
        SUCCESS: colors.green,
        WARNING: colors.yellow,
        ERROR: colors.red,
        SYNC: colors.cyan
    };

    const color = levelColors[level] || colors.reset;
    const consoleMsg = `${color}[${level}]${colors.reset} ${timestamp} - ${message}`;
    console.log(consoleMsg);

    if (data) {
        console.log(colors.reset + JSON.stringify(data, null, 2));
    }

    // File logging
    try {
        await fs.appendFile(
            LOG_FILE,
            JSON.stringify(logEntry) + '\n',
            'utf8'
        );
    } catch (err) {
        console.error('Failed to write to log file:', err.message);
    }

    // Add to history
    syncHistory.unshift({
        timestamp,
        level,
        message,
        data
    });

    if (syncHistory.length > MAX_HISTORY) {
        syncHistory.pop();
    }
}

// Execute sync script
async function syncWorkflow(workflowId, workflowName) {
    const startTime = Date.now();

    try {
        await log('SYNC', `Starting sync for workflow: ${workflowName}`, { workflowId });

        const command = `${SYNC_SCRIPT} "${workflowId}" --force`;
        const { stdout, stderr } = await execPromise(command, {
            maxBuffer: 10 * 1024 * 1024
        });

        const duration = Date.now() - startTime;

        if (stdout.includes('Successfully wrote workflow') || stdout.includes('Sync Complete')) {
            await log('SUCCESS', `Synced ${workflowName} in ${duration}ms`, {
                workflowId,
                duration,
                output: stdout.substring(0, 200)
            });

            return { success: true, duration, output: stdout };
        } else {
            await log('WARNING', `Sync completed but with warnings: ${workflowName}`, {
                workflowId,
                stderr: stderr.substring(0, 200)
            });

            return { success: true, duration, warnings: stderr };
        }
    } catch (error) {
        const duration = Date.now() - startTime;

        await log('ERROR', `Failed to sync ${workflowName}`, {
            workflowId,
            error: error.message,
            duration
        });

        return { success: false, error: error.message, duration };
    }
}

// Handle notification with debouncing
async function handleNotification(payload) {
    try {
        const data = JSON.parse(payload);
        const { workflow_id, workflow_name, updated_at, action } = data;

        await log('INFO', `Received ${action} notification for: ${workflow_name}`, {
            workflow_id,
            updated_at
        });

        // Clear existing timeout if any
        if (pendingSyncs.has(workflow_id)) {
            clearTimeout(pendingSyncs.get(workflow_id));
        }

        // Set new debounced timeout
        const timeout = setTimeout(async () => {
            pendingSyncs.delete(workflow_id);
            await syncWorkflow(workflow_id, workflow_name);
        }, DEBOUNCE_MS);

        pendingSyncs.set(workflow_id, timeout);

        await log('INFO', `Debouncing sync for ${workflow_name} (${DEBOUNCE_MS}ms)`);

    } catch (error) {
        await log('ERROR', 'Failed to parse notification payload', {
            payload,
            error: error.message
        });
    }
}

// Main daemon function
async function startDaemon() {
    const client = new Client(DB_CONFIG);

    try {
        // Connect to PostgreSQL
        await log('INFO', 'Connecting to PostgreSQL...');
        await client.connect();
        await log('SUCCESS', 'Connected to PostgreSQL', {
            host: DB_CONFIG.host,
            database: DB_CONFIG.database
        });

        // Listen to the channel
        await client.query(`LISTEN ${CHANNEL}`);
        await log('SUCCESS', `Listening on channel: ${CHANNEL}`);

        // Handle notifications
        client.on('notification', async (msg) => {
            if (msg.channel === CHANNEL) {
                await handleNotification(msg.payload);
            }
        });

        // Handle connection errors
        client.on('error', async (err) => {
            await log('ERROR', 'PostgreSQL client error', {
                error: err.message,
                stack: err.stack
            });

            // Attempt to reconnect
            setTimeout(() => {
                log('INFO', 'Attempting to reconnect...');
                startDaemon();
            }, 5000);
        });

        // Heartbeat check (keep connection alive)
        setInterval(async () => {
            try {
                await client.query('SELECT 1');
            } catch (err) {
                await log('WARNING', 'Heartbeat failed', { error: err.message });
            }
        }, 30000); // Every 30 seconds

        // Banner
        console.log(`
${colors.bright}${colors.blue}╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   🔄 n8n Workflow Auto-Sync Daemon                        ║
║                                                            ║
║   📡 Listening: ${CHANNEL.padEnd(38)}║
║   🗄️  Database: ${DB_CONFIG.database.padEnd(38)}║
║   ⏱️  Debounce: ${DEBOUNCE_MS}ms${' '.repeat(37)}║
║   📝 Log File: sync-daemon.log${' '.repeat(25)}║
║                                                            ║
╚════════════════════════════════════════════════════════════╝${colors.reset}

${colors.green}Daemon is running! Workflows will auto-sync when saved in n8n.${colors.reset}
${colors.cyan}Press Ctrl+C to stop.${colors.reset}
        `);

    } catch (error) {
        await log('ERROR', 'Failed to start daemon', {
            error: error.message,
            stack: error.stack
        });

        process.exit(1);
    }
}

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n');
    await log('INFO', 'Received SIGINT, shutting down gracefully...');

    // Clear pending syncs
    for (const [workflowId, timeout] of pendingSyncs.entries()) {
        clearTimeout(timeout);
        await log('INFO', `Cancelled pending sync for workflow: ${workflowId}`);
    }

    await log('INFO', 'Daemon stopped');
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('\n');
    await log('INFO', 'Received SIGTERM, shutting down gracefully...');
    process.exit(0);
});

// Handle uncaught errors
process.on('uncaughtException', async (error) => {
    await log('ERROR', 'Uncaught exception', {
        error: error.message,
        stack: error.stack
    });
    process.exit(1);
});

process.on('unhandledRejection', async (reason, promise) => {
    await log('ERROR', 'Unhandled rejection', {
        reason: String(reason),
        promise: String(promise)
    });
});

// Start the daemon
startDaemon();

// Export for testing
module.exports = {
    syncWorkflow,
    handleNotification,
    log
};
