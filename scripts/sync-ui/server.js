#!/usr/bin/env node

const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs').promises;
const util = require('util');
const execPromise = util.promisify(exec);

const app = express();
const PORT = process.env.SYNC_UI_PORT || 3456;

// Middleware
app.use(express.json());
app.use(express.static(__dirname));

// Detect if running in Docker
const IS_DOCKER = fs.existsSync('/.dockerenv');
const SCRIPTS_DIR = IS_DOCKER ? '/app/scripts' : path.join(__dirname, '..');
const WORKFLOWS_DIR = IS_DOCKER ? '/app/json-flows' : path.join(__dirname, '../../json-flows');

// Helper function to run shell commands
async function runCommand(command) {
    try {
        const { stdout, stderr } = await execPromise(command, {
            cwd: SCRIPTS_DIR,
            maxBuffer: 10 * 1024 * 1024 // 10MB buffer
        });
        return { success: true, stdout, stderr };
    } catch (error) {
        return { success: false, error: error.message, stdout: error.stdout, stderr: error.stderr };
    }
}

// Helper to parse workflow list from PostgreSQL
async function getWorkflowsFromDB() {
    const query = `
        SELECT
            id,
            name,
            EXTRACT(EPOCH FROM "updatedAt")::bigint as updated_epoch,
            TO_CHAR("updatedAt" AT TIME ZONE 'America/Phoenix', 'YYYY-MM-DD HH24:MI:SS') as db_updated
        FROM workflow_entity
        ORDER BY "updatedAt" DESC
        LIMIT 50;
    `;

    const command = `docker exec ai-postgres psql -U ai_user -d ai_assistant -t -A -F'|' -c "${query.replace(/\n/g, ' ')}"`;

    const result = await runCommand(command);

    if (!result.success) {
        throw new Error('Failed to query database: ' + result.error);
    }

    const workflows = [];
    const lines = result.stdout.trim().split('\n').filter(line => line.trim());

    for (const line of lines) {
        const [id, name, updated_epoch, db_updated] = line.split('|');

        if (!id || !name) continue;

        // Check if local file exists and get its modification time
        const localFile = path.join(WORKFLOWS_DIR, `${name}.json`);
        let fileModified = null;
        let file_mtime_epoch = 0;

        try {
            const stats = await fs.stat(localFile);
            file_mtime_epoch = Math.floor(stats.mtimeMs / 1000);

            // Convert to Arizona time
            const { stdout: azTime } = await runCommand(
                `TZ='America/Phoenix' date -d "@${file_mtime_epoch}" '+%Y-%m-%d %H:%M:%S'`
            );
            fileModified = azTime.trim();
        } catch (err) {
            // File doesn't exist
            fileModified = null;
        }

        // Determine status
        let status = 'unknown';
        let statusText = 'Unknown';
        let statusClass = 'unknown';

        const diffSeconds = parseInt(updated_epoch) - file_mtime_epoch;

        if (file_mtime_epoch === 0) {
            status = 'not_exists';
            statusText = 'Not Exists';
            statusClass = 'unknown';
        } else if (Math.abs(diffSeconds) < 5) {
            status = 'synced';
            statusText = '✓ Synced';
            statusClass = 'synced';
        } else if (diffSeconds > 0) {
            status = 'db_newer';
            statusText = 'DB Newer';
            statusClass = 'outdated';
        } else {
            status = 'file_newer';
            statusText = 'Local Newer';
            statusClass = 'newer';
        }

        workflows.push({
            id,
            name,
            dbUpdated: db_updated,
            fileModified,
            status,
            statusText,
            statusClass,
            diffSeconds
        });
    }

    return workflows;
}

// API Routes

// Get all workflows with status
app.get('/api/workflows', async (req, res) => {
    try {
        const workflows = await getWorkflowsFromDB();
        res.json(workflows);
    } catch (error) {
        console.error('Error fetching workflows:', error);
        res.status(500).json({ error: error.message });
    }
});

// Sync a workflow
app.post('/api/sync', async (req, res) => {
    const { workflowId, force = false, archive = false } = req.body;

    if (!workflowId) {
        return res.status(400).json({ error: 'Workflow ID is required' });
    }

    try {
        // Build sync command
        let command = `./sync-n8n-workflow.sh "${workflowId}"`;

        if (force) {
            command += ' --force';
        }

        // If archive requested, we need to simulate the interactive choice
        // For now, we'll use force flag and manually archive if needed
        if (archive) {
            // First, archive the file
            const workflow = (await getWorkflowsFromDB()).find(w => w.id === workflowId);
            if (workflow && workflow.fileModified) {
                const archiveDate = new Date().toISOString().split('T')[0].replace(/-/g, '');
                const archiveDir = path.join(WORKFLOWS_DIR, '_archive', archiveDate);

                await fs.mkdir(archiveDir, { recursive: true });

                const sourceFile = path.join(WORKFLOWS_DIR, `${workflow.name}.json`);
                const destFile = path.join(archiveDir, `${workflow.name}.json`);

                await fs.copyFile(sourceFile, destFile);

                // Log to SYNC_LOG.md
                const logFile = path.join(archiveDir, 'SYNC_LOG.md');
                const timestamp = new Date().toLocaleString('en-US', { timeZone: 'America/Phoenix' });
                const logEntry = `
## ${timestamp} MST
- **Workflow**: ${workflow.name}
- **File Modified**: ${workflow.fileModified}
- **DB Updated**: ${workflow.dbUpdated}
- **Action**: Archived local version via UI, pulled DB version
- **User**: Web UI

`;
                await fs.appendFile(logFile, logEntry);
            }

            command += ' --force';
        }

        const result = await runCommand(command);

        if (result.success || result.stdout.includes('Successfully wrote workflow')) {
            res.json({
                success: true,
                message: archive
                    ? 'Workflow archived and synced successfully!'
                    : 'Workflow synced successfully!',
                log: result.stdout + '\n' + (result.stderr || '')
            });
        } else {
            res.json({
                success: false,
                error: result.error || 'Sync failed',
                log: result.stdout + '\n' + (result.stderr || '')
            });
        }
    } catch (error) {
        console.error('Sync error:', error);
        res.status(500).json({
            error: error.message,
            success: false
        });
    }
});

// Get sync script output (for debugging)
app.get('/api/sync-status/:workflowId', async (req, res) => {
    const { workflowId } = req.params;

    try {
        const command = `./sync-n8n-workflow.sh "${workflowId}" --dry-run`;
        const result = await runCommand(command);

        res.json({
            success: true,
            output: result.stdout,
            error: result.stderr
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        timezone: 'America/Phoenix'
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ⚡ n8n Workflow Sync UI Server                         ║
║                                                           ║
║   🌐 Running on: http://localhost:${PORT}                    ║
║   🕐 Timezone: America/Phoenix (MST/MDT)                  ║
║   📂 Workflows: /mnt/volume_nyc1_01/idudesRAG/json-flows  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Ready to sync workflows! 🚀
    `);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n\nShutting down server...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n\nShutting down server...');
    process.exit(0);
});
