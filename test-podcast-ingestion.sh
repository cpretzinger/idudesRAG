#!/bin/bash

# TEST PODCAST INGESTION - EXACT STEPS

echo "🎙️ Testing Podcast Ingestion with Chunking..."

# Test payload - sample podcast transcript
curl -X POST https://ai.thirdeyediagnostics.com/webhook/idudesRAG/ingest-podcast \
  -H "Content-Type: application/json" \
  -d '{
    "transcript": "[00:01:23] Host: Welcome to Insurance Dudes episode 147. Today we have John Smith talking about objection handling.\n[00:01:45] John: Thanks for having me! Objection handling is crucial in insurance sales.\n[00:02:10] Host: What is the biggest mistake agents make?\n[00:02:30] John: They take objections personally instead of seeing them as buying signals. When someone says \"I need to think about it\", that is actually engagement.\n[00:03:15] Host: Can you give us a specific example?\n[00:03:45] John: Sure! Last week I had a client say \"Your premium is too high\". Instead of defending the price, I asked \"What specific coverage are you most concerned about paying for?\" This opened up a real conversation about their priorities.",
    "episode_title": "Episode 147 - Objection Handling Mastery",
    "date": "2025-01-05",
    "guest": "John Smith",
    "duration": "45 minutes",
    "topics": ["objection handling", "sales techniques", "insurance sales"],
    "spaces_url": "https://datainjestion.nyc3.cdn.digitaloceanspaces.com/episode-147.mp3"
  }'

echo -e "\n\n✅ Test complete! Check your database for chunks."