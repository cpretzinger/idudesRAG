-- =====================================================
-- n8n Workflow Auto-Sync Trigger Setup
-- =====================================================
--
-- PURPOSE: Automatically notify sync daemon when workflows are saved in n8n
-- SAFETY: READ ONLY - Only sends notifications, never modifies data
--
-- Installation:
--   docker exec ai-postgres psql -U ai_user -d ai_assistant -f /path/to/setup-workflow-trigger.sql
--
-- Uninstall:
--   DROP TRIGGER IF EXISTS workflow_update_trigger ON workflow_entity;
--   DROP FUNCTION IF EXISTS notify_workflow_change();
-- =====================================================

-- Create notification function
CREATE OR REPLACE FUNCTION notify_workflow_change()
RETURNS trigger AS $$
DECLARE
  payload TEXT;
BEGIN
  -- Build JSON payload with workflow info
  payload := json_build_object(
    'workflow_id', NEW.id,
    'workflow_name', NEW.name,
    'updated_at', EXTRACT(EPOCH FROM NEW."updatedAt"),
    'action', TG_OP
  )::TEXT;

  -- Send notification to 'workflow_updates' channel
  PERFORM pg_notify('workflow_updates', payload);

  -- Log to application (optional - for debugging)
  RAISE NOTICE 'Workflow changed: % (%) at %', NEW.name, NEW.id, NEW."updatedAt";

  -- Return NEW unchanged (required for AFTER trigger)
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on workflow_entity table
DROP TRIGGER IF EXISTS workflow_update_trigger ON workflow_entity;

CREATE TRIGGER workflow_update_trigger
AFTER UPDATE ON workflow_entity
FOR EACH ROW
WHEN (OLD.* IS DISTINCT FROM NEW.*)  -- Only fire if data actually changed
EXECUTE FUNCTION notify_workflow_change();

-- Grant necessary permissions (if needed)
-- GRANT EXECUTE ON FUNCTION notify_workflow_change() TO ai_user;

-- Verify trigger was created
SELECT
  tgname AS trigger_name,
  tgenabled AS enabled,
  tgrelid::regclass AS table_name
FROM pg_trigger
WHERE tgname = 'workflow_update_trigger';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Workflow auto-sync trigger installed successfully!';
  RAISE NOTICE '   - Trigger: workflow_update_trigger';
  RAISE NOTICE '   - Function: notify_workflow_change()';
  RAISE NOTICE '   - Channel: workflow_updates';
  RAISE NOTICE '   - Safety: READ ONLY (no data modifications)';
  RAISE NOTICE '';
  RAISE NOTICE 'To test: UPDATE workflow_entity SET name = name WHERE id = (SELECT id FROM workflow_entity LIMIT 1);';
  RAISE NOTICE 'To remove: DROP TRIGGER workflow_update_trigger ON workflow_entity;';
END $$;
