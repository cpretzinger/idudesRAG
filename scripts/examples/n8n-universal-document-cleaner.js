/**
 * UNIVERSAL DOCUMENT CLEANER FOR N8N CODE NODE
 * ============================================
 * 
 * Intelligently processes ANY document type with adaptive cleaning strategies.
 * Auto-detects format and applies appropriate transformations.
 * 
 * SUPPORTED FORMATS:
 * - Podcast transcripts (with episode delimiters, speakers, timestamps)
 * - PDF extracts (complex formatting, artifacts)
 * - Plain text articles
 * - Emails (headers, signatures, quoted text)
 * - HTML documents
 * - Markdown files
 * - Mixed/unknown formats
 * 
 * USAGE IN N8N CODE NODE:
 * ------------------------
 * Input: $json.text_content (raw document text)
 * Output: Array of cleaned chunks with processing metadata
 * 
 * @param {string} textContent - Raw document text from previous node
 * @param {number} targetChunkSize - Desired chunk size (default: 1000)
 * @param {number} chunkOverlap - Overlap between chunks (default: 200)
 * @param {object} options - Processing options
 * @returns {Array<object>} Cleaned chunks with metadata
 */

// ==========================
// CONFIGURATION
// ==========================

// Try multiple possible input field names (prioritize n8n workflow format)
const textContent =
  $json.pageContent ||    // n8n workflow format (from Document Loader)
  $json.text_content ||   // Alternative format
  $json.data ||           // Original expected format
  $json.content ||        // Common format
  $json.text ||           // Simple format
  '';

// Validate input before proceeding
if (!textContent || textContent.trim().length === 0) {
  return [{
    json: {
      error: 'No text content found in input',
      hint: 'Expected one of: pageContent, text_content, data, content, or text',
      received_fields: Object.keys($json),
      received_data: $json
    }
  }];
}

const targetChunkSize = $json.chunk_size || 1000;
const chunkOverlap = $json.chunk_overlap || 200;

const options = {
  preserveSpeakerLabels: $json.preserve_speakers ?? false,
  preserveTimestamps: $json.preserve_timestamps ?? false,
  preserveEpisodeStructure: $json.preserve_episodes ?? true,
  aggressiveWhitespace: $json.aggressive_whitespace ?? true,
  removeEmailHeaders: $json.remove_email_headers ?? true,
  removeSignatures: $json.remove_signatures ?? true,
  minConfidenceScore: $json.min_confidence ?? 0.7
};

try {
  // Phase 1: Auto-detect document structure
  const detection = detectDocumentStructure(textContent);
  
  console.log(`🔍 DETECTION RESULTS:
    Format: ${detection.likelyFormat} (${Math.round(detection.confidence * 100)}% confidence)
    Indicators: ${detection.indicators.join(', ')}
  `);

  // Phase 2: Apply adaptive cleaning pipeline
  const cleanedText = applyAdaptiveCleaning(textContent, detection, options);
  
  // Phase 3: Intelligent chunking
  const chunks = intelligentChunking(cleanedText, detection, targetChunkSize, chunkOverlap);
  
  // Phase 4: Add metadata to each chunk
  const processedChunks = chunks.map((chunk, index) => 
    enrichChunkMetadata(chunk, index, chunks.length, detection, textContent.length)
  );

  console.log(`✅ PROCESSING COMPLETE:
    Format: ${detection.likelyFormat}
    Original: ${textContent.length} chars
    Cleaned: ${cleanedText.length} chars
    Reduction: ${Math.round((1 - cleanedText.length / textContent.length) * 100)}%
    Chunks: ${processedChunks.length}
    Applied: ${detection.indicators.join(', ')}
  `);

  return processedChunks;

} catch (error) {
  console.error('❌ UNIVERSAL CLEANER ERROR:', error);
  
  // Fallback: Return basic cleaned version
  const fallbackClean = basicCleanup(textContent);
  const fallbackChunks = simpleChunking(fallbackClean, targetChunkSize, chunkOverlap);
  
  return fallbackChunks.map((chunk, index) => ({
    json: {
      text_chunk: chunk,
      chunk_index: index,
      total_chunks: fallbackChunks.length,
      detected_format: 'unknown',
      processing_applied: ['fallback_cleanup'],
      confidence_score: 0.5,
      metadata: {
        original_length: textContent.length,
        cleaned_length: fallbackClean.length,
        reduction_percentage: Math.round((1 - fallbackClean.length / textContent.length) * 100),
        error: error.message
      }
    }
  }));
}

// ==========================
// PHASE 1: DETECTION ENGINE
// ==========================

function detectDocumentStructure(text) {
  const indicators = [];
  let confidence = 0;
  
  // Episode/Podcast markers
  const hasEpisodeDelimiters = /-----BEGIN|-----END|Episode \d+/i.test(text);
  if (hasEpisodeDelimiters) {
    indicators.push('episode_delimiters');
    confidence += 0.3;
  }
  
  // HTML content
  const hasHTMLTags = /<[^>]+>/g.test(text);
  const htmlTagCount = (text.match(/<[^>]+>/g) || []).length;
  if (hasHTMLTags && htmlTagCount > 5) {
    indicators.push('html_tags');
    confidence += 0.2;
  }
  
  // HTML entities
  const hasHTMLEntities = /&[a-z]+;|&#\d+;/gi.test(text);
  if (hasHTMLEntities) {
    indicators.push('html_entities');
    confidence += 0.1;
  }
  
  // Speaker labels (podcast/interview format)
  const hasSpeakerLabels = /<cite>|Speaker \d+:|[A-Z][a-z]+ [A-Z][a-z]+:/i.test(text);
  if (hasSpeakerLabels) {
    indicators.push('speaker_labels');
    confidence += 0.2;
  }
  
  // Timestamps
  const hasTimestamps = /<time>|\d{1,2}:\d{2}:\d{2}|\[\d{2}:\d{2}\]/i.test(text);
  if (hasTimestamps) {
    indicators.push('timestamps');
    confidence += 0.15;
  }
  
  // Email indicators
  const hasEmailHeaders = /^(From|To|Subject|Date):/mi.test(text) ||
                          /^On.*wrote:$/mi.test(text);
  if (hasEmailHeaders) {
    indicators.push('email_headers');
    confidence += 0.25;
  }
  
  // Email signature
  const hasSignature = /^--\s*$|Best regards|Sincerely|Sent from my/mi.test(text);
  if (hasSignature) {
    indicators.push('signature');
    confidence += 0.1;
  }
  
  // Markdown formatting
  const hasMarkdown = /^#{1,6}\s|\*\*|__|\[.*\]\(.*\)|```/m.test(text);
  if (hasMarkdown) {
    indicators.push('markdown');
    confidence += 0.15;
  }
  
  // Urdu content
  const hasUrduContent = /[\u0600-\u06FF]/.test(text);
  if (hasUrduContent) {
    indicators.push('urdu_script');
    confidence += 0.1;
  }
  
  // Determine likely format
  let likelyFormat = 'unknown';
  
  if (hasEpisodeDelimiters && hasSpeakerLabels) {
    likelyFormat = 'podcast_transcript';
    confidence = Math.min(confidence + 0.2, 1.0);
  } else if (hasEmailHeaders) {
    likelyFormat = 'email';
    confidence = Math.min(confidence + 0.15, 1.0);
  } else if (hasHTMLTags && htmlTagCount > 20) {
    likelyFormat = 'html_document';
    confidence = Math.min(confidence + 0.1, 1.0);
  } else if (hasMarkdown) {
    likelyFormat = 'markdown_document';
    confidence = Math.min(confidence + 0.1, 1.0);
  } else if (hasSpeakerLabels || hasTimestamps) {
    likelyFormat = 'transcript';
    confidence = Math.min(confidence + 0.1, 1.0);
  } else if (!hasHTMLTags && !hasEmailHeaders) {
    likelyFormat = 'plain_text';
    confidence = Math.min(confidence + 0.05, 1.0);
  }
  
  return {
    hasEpisodeDelimiters,
    hasHTMLTags,
    hasHTMLEntities,
    hasSpeakerLabels,
    hasTimestamps,
    hasEmailHeaders,
    hasSignature,
    hasMarkdown,
    hasUrduContent,
    likelyFormat,
    confidence: Math.min(confidence, 1.0),
    indicators
  };
}

// ==========================
// PHASE 2: ADAPTIVE CLEANING
// ==========================

function applyAdaptiveCleaning(text, detection, options) {
  let cleaned = text;
  const appliedSteps = [];
  
  // Step 1: Episode/Section separation (if detected)
  if (detection.hasEpisodeDelimiters && options.preserveEpisodeStructure) {
    // Keep episode markers but normalize them
    cleaned = cleaned.replace(/-----BEGIN EPISODE.*?-----/gi, '\n[EPISODE_START]\n');
    cleaned = cleaned.replace(/-----END EPISODE.*?-----/gi, '\n[EPISODE_END]\n');
    appliedSteps.push('episode_normalization');
  } else if (detection.hasEpisodeDelimiters) {
    // Remove episode markers entirely
    cleaned = cleaned.replace(/-----BEGIN EPISODE.*?-----/gi, '');
    cleaned = cleaned.replace(/-----END EPISODE.*?-----/gi, '');
    appliedSteps.push('episode_removal');
  }
  
  // Step 2: Email-specific cleaning
  if (detection.hasEmailHeaders && options.removeEmailHeaders) {
    // Remove email headers
    cleaned = cleaned.replace(/^(From|To|Subject|Date|Cc|Bcc):.*$/gmi, '');
    cleaned = cleaned.replace(/^On.*wrote:$/gmi, '');
    appliedSteps.push('email_headers_removed');
  }
  
  if (detection.hasSignature && options.removeSignatures) {
    // Remove common signature patterns
    cleaned = cleaned.replace(/^--\s*$.*$/gms, '');
    cleaned = cleaned.replace(/^(Best regards|Sincerely|Thanks|Cheers|Regards),.*/gmi, '');
    cleaned = cleaned.replace(/Sent from my (iPhone|iPad|Android|BlackBerry).*/gi, '');
    appliedSteps.push('signatures_removed');
  }
  
  // Step 3: HTML tag removal (if detected)
  if (detection.hasHTMLTags) {
    // Remove HTML tags but preserve some semantic structure
    cleaned = cleaned.replace(/<br\s*\/?>/gi, '\n');
    cleaned = cleaned.replace(/<\/p>/gi, '\n\n');
    cleaned = cleaned.replace(/<[^>]+>/g, '');
    appliedSteps.push('html_tags_removed');
  }
  
  // Step 4: HTML entity normalization
  if (detection.hasHTMLEntities) {
    const entityMap = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&nbsp;': ' ',
      '&mdash;': '—',
      '&ndash;': '–',
      '&rsquo;': '\'',
      '&lsquo;': '\'',
      '&rdquo;': '"',
      '&ldquo;': '"',
      '&hellip;': '...'
    };
    
    for (const [entity, char] of Object.entries(entityMap)) {
      cleaned = cleaned.replace(new RegExp(entity, 'g'), char);
    }
    
    // Handle numeric entities
    cleaned = cleaned.replace(/&#(\d+);/g, (match, code) => 
      String.fromCharCode(parseInt(code))
    );
    
    appliedSteps.push('html_entities_normalized');
  }
  
  // Step 5: Speaker label handling
  if (detection.hasSpeakerLabels) {
    if (!options.preserveSpeakerLabels) {
      cleaned = cleaned.replace(/<cite>.*?<\/cite>/gi, '');
      cleaned = cleaned.replace(/Speaker \d+:/gi, '');
      cleaned = cleaned.replace(/^[A-Z][a-z]+ [A-Z][a-z]+:\s*/gmi, '');
      appliedSteps.push('speaker_labels_removed');
    } else {
      cleaned = cleaned.replace(/<cite>(.*?)<\/cite>/gi, '$1:');
      appliedSteps.push('speaker_labels_normalized');
    }
  }
  
  // Step 6: Timestamp handling
  if (detection.hasTimestamps) {
    if (!options.preserveTimestamps) {
      cleaned = cleaned.replace(/<time>.*?<\/time>/gi, '');
      cleaned = cleaned.replace(/\d{1,2}:\d{2}:\d{2}/g, '');
      cleaned = cleaned.replace(/\[\d{2}:\d{2}\]/g, '');
      appliedSteps.push('timestamps_removed');
    } else {
      cleaned = cleaned.replace(/<time>(.*?)<\/time>/gi, '[$1]');
      appliedSteps.push('timestamps_normalized');
    }
  }
  
  // Step 7: Markdown preservation/removal
  if (detection.hasMarkdown) {
    // Convert markdown to plain text while preserving structure
    cleaned = cleaned.replace(/^#{1,6}\s+(.+)$/gm, '$1\n');
    cleaned = cleaned.replace(/\*\*(.+?)\*\*/g, '$1');
    cleaned = cleaned.replace(/__(.+?)__/g, '$1');
    cleaned = cleaned.replace(/\[(.+?)\]\(.+?\)/g, '$1');
    cleaned = cleaned.replace(/```[\s\S]*?```/g, '');
    appliedSteps.push('markdown_normalized');
  }
  
  // Step 8: Whitespace normalization (ALWAYS)
  if (options.aggressiveWhitespace) {
    cleaned = cleaned.replace(/[ \t]+/g, ' ');           // Multiple spaces → single space
    cleaned = cleaned.replace(/\n\s*\n\s*\n/g, '\n\n');  // Multiple newlines → double newline
    cleaned = cleaned.replace(/^\s+|\s+$/gm, '');        // Trim lines
    appliedSteps.push('aggressive_whitespace');
  } else {
    cleaned = cleaned.replace(/[ \t]{2,}/g, ' ');
    cleaned = cleaned.replace(/\n{3,}/g, '\n\n');
    appliedSteps.push('basic_whitespace');
  }
  
  // Step 9: Special character cleanup (ALWAYS)
  cleaned = cleaned.replace(/\u200B/g, '');              // Zero-width spaces
  cleaned = cleaned.replace(/\u00A0/g, ' ');             // Non-breaking spaces
  cleaned = cleaned.replace(/[\u2018\u2019]/g, "'");     // Smart quotes
  cleaned = cleaned.replace(/[\u201C\u201D]/g, '"');     // Smart double quotes
  cleaned = cleaned.replace(/\u2013/g, '-');             // En dash
  cleaned = cleaned.replace(/\u2014/g, '—');             // Em dash (preserve)
  cleaned = cleaned.replace(/\u2026/g, '...');           // Ellipsis
  appliedSteps.push('special_chars_normalized');
  
  // Step 10: Final cleanup
  cleaned = cleaned.trim();
  
  console.log(`🧹 CLEANING APPLIED: ${appliedSteps.join(' → ')}`);
  
  return cleaned;
}

// ==========================
// PHASE 3: INTELLIGENT CHUNKING
// ==========================

function intelligentChunking(text, detection, targetSize, overlap) {
  const chunks = [];
  
  // Strategy 1: Episode-based chunking (if applicable)
  if (detection.hasEpisodeDelimiters && text.includes('[EPISODE_START]')) {
    const episodes = text.split('[EPISODE_START]')
      .filter(ep => ep.trim().length > 0)
      .map(ep => ep.replace('[EPISODE_END]', '').trim());
    
    for (const episode of episodes) {
      if (episode.length <= targetSize) {
        chunks.push(episode);
      } else {
        // Episode too large, chunk it further
        chunks.push(...sentenceBasedChunking(episode, targetSize, overlap));
      }
    }
    
    return chunks;
  }
  
  // Strategy 2: Paragraph-aware chunking
  const paragraphs = text.split('\n\n').filter(p => p.trim().length > 0);
  
  let currentChunk = '';
  
  for (const paragraph of paragraphs) {
    if ((currentChunk + paragraph).length <= targetSize) {
      currentChunk += (currentChunk ? '\n\n' : '') + paragraph;
    } else {
      if (currentChunk) {
        chunks.push(currentChunk.trim());
      }
      
      if (paragraph.length > targetSize) {
        // Paragraph too large, use sentence-based chunking
        chunks.push(...sentenceBasedChunking(paragraph, targetSize, overlap));
        currentChunk = '';
      } else {
        currentChunk = paragraph;
      }
    }
  }
  
  if (currentChunk) {
    chunks.push(currentChunk.trim());
  }
  
  // Apply overlap between chunks
  return applyChunkOverlap(chunks, overlap);
}

function sentenceBasedChunking(text, targetSize, overlap) {
  // Split on sentence boundaries
  const sentences = text.match(/[^.!?]+[.!?]+/g) || [text];
  const chunks = [];
  let currentChunk = '';
  
  for (const sentence of sentences) {
    if ((currentChunk + sentence).length <= targetSize) {
      currentChunk += sentence;
    } else {
      if (currentChunk) {
        chunks.push(currentChunk.trim());
      }
      currentChunk = sentence;
    }
  }
  
  if (currentChunk) {
    chunks.push(currentChunk.trim());
  }
  
  return chunks;
}

function applyChunkOverlap(chunks, overlapSize) {
  if (chunks.length <= 1 || overlapSize === 0) {
    return chunks;
  }
  
  const overlappedChunks = [];
  
  for (let i = 0; i < chunks.length; i++) {
    if (i === 0) {
      overlappedChunks.push(chunks[i]);
    } else {
      const previousChunk = chunks[i - 1];
      const overlap = previousChunk.slice(-overlapSize);
      overlappedChunks.push(overlap + ' ' + chunks[i]);
    }
  }
  
  return overlappedChunks;
}

// ==========================
// PHASE 4: METADATA ENRICHMENT
// ==========================

function enrichChunkMetadata(chunk, index, totalChunks, detection, originalLength) {
  const cleanedLength = chunk.length;
  const reductionPercentage = Math.round((1 - cleanedLength / originalLength) * 100);
  
  // Extract additional metadata
  const speakerCount = (chunk.match(/[A-Z][a-z]+ [A-Z][a-z]+:/g) || []).length;
  const timestampCount = (chunk.match(/\d{1,2}:\d{2}:\d{2}|\[\d{2}:\d{2}\]/g) || []).length;
  const episodeMatch = chunk.match(/\[EPISODE_START\]/);
  
  const metadata = {
    original_length: originalLength,
    cleaned_length: cleanedLength,
    reduction_percentage: reductionPercentage
  };
  
  if (episodeMatch) {
    metadata.episode_id = `episode_${index}`;
  }
  
  if (speakerCount > 0) {
    metadata.speaker_count = speakerCount;
  }
  
  if (timestampCount > 0) {
    metadata.timestamp_count = timestampCount;
  }
  
  return {
    json: {
      text_chunk: chunk,
      chunk_index: index,
      total_chunks: totalChunks,
      detected_format: detection.likelyFormat,
      processing_applied: detection.indicators,
      confidence_score: detection.confidence,
      metadata
    }
  };
}

// ==========================
// FALLBACK FUNCTIONS
// ==========================

function basicCleanup(text) {
  return text
    .replace(/<[^>]+>/g, '')                    // Remove HTML tags
    .replace(/&[a-z]+;|&#\d+;/gi, ' ')          // Remove entities
    .replace(/[ \t]+/g, ' ')                     // Normalize spaces
    .replace(/\n{3,}/g, '\n\n')                  // Normalize newlines
    .replace(/^\s+|\s+$/gm, '')                  // Trim lines
    .trim();
}

function simpleChunking(text, targetSize, overlap) {
  const chunks = [];
  let start = 0;
  
  while (start < text.length) {
    const end = Math.min(start + targetSize, text.length);
    chunks.push(text.slice(start, end));
    start += targetSize - overlap;
  }
  
  return chunks;
}