-- Verify current schema for documents table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'core'
  AND table_name = 'documents'
ORDER BY ordinal_position;

-- Verify current schema for document_embeddings table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'core'
  AND table_name = 'document_embeddings'
ORDER BY ordinal_position;

-- Check if spaces_url column still exists (should be gone)
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'core'
  AND table_name = 'documents'
  AND column_name = 'spaces_url';

-- Test insert with the Google Drive data
-- This will show if the schema can handle the new fields
DO $$
DECLARE
    test_metadata JSONB := '{
        "source": "google_drive",
        "blobType": "text/plain",
        "loc": {
            "lines": {
                "from": 1,
                "to": 318
            }
        },
        "filename": "⏺ 2025 INSURANCE DUDES CONTENT DOMINATION PLAYBOOK",
        "file_type": "application/vnd.google-apps.document",
        "file_size": 6493,
        "timestamp": "2025-10-07T21:15:54.902Z",
        "document_id": "a9f1a57d-c419-44bc-b21e-b2f2c786b79e",
        "drive_file_id": "1VdRG8IMYrH8gIU_-7bBP8DzQzhgoTj1edkZ3g7TFAJI"
    }';
    test_filename TEXT := '⏺ 2025 INSURANCE DUDES CONTENT DOMINATION PLAYBOOK';
BEGIN
    -- Test if we can extract values from this metadata structure
    RAISE NOTICE 'Filename from metadata: %', test_metadata->>'filename';
    RAISE NOTICE 'File type from metadata: %', test_metadata->>'file_type';
    RAISE NOTICE 'File size from metadata: %', (test_metadata->>'file_size')::bigint;
    RAISE NOTICE 'Source from metadata: %', test_metadata->>'source';
    RAISE NOTICE 'Document ID from metadata: %', test_metadata->>'document_id';
    RAISE NOTICE 'Drive file ID from metadata: %', test_metadata->>'drive_file_id';
END $$;
