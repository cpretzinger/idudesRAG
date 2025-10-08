/**
 * n8n Code Node: Transcript Cleaning & Contextual Chunking
 * 
 * PURPOSE: Process raw podcast transcript data for optimal text embedding
 * INPUT: $json.data (raw concatenated transcript string with HTML tags, timestamps, metadata)
 * OUTPUT: Array of n8n items with clean text chunks
 * 
 * PROCESSING STEPS:
 * 1. Episode separation (remove BEGIN/END delimiters and headers/footers)
 * 2. HTML/XML tag stripping
 * 3. HTML entity normalization
 * 4. Whitespace cleanup
 * 5. Contextual chunking at sentence boundaries (~400 chars, max 500)
 */

// ============================================================================
// MAIN PROCESSING FUNCTION
// ============================================================================

try {
  // Input validation
  const rawData = $json.data;
  
  if (!rawData || typeof rawData !== 'string') {
    throw new Error('Invalid input: $json.data must be a non-empty string');
  }

  // ============================================================================
  // STEP 1: EPISODE SEPARATION & HEADER/FOOTER REMOVAL
  // ============================================================================
  
  const episodeRegex = /-----BEGIN.*?-----END[^\n]*/gs;
  const episodes = rawData.match(episodeRegex) || [];
  
  if (episodes.length === 0) {
    console.log('Warning: No episode delimiters found, processing entire input as single episode');
  }
  
  // Remove delimiters and concatenate all episode content
  let concatenatedText = episodes.length > 0 
    ? episodes.map(ep => {
        // Remove BEGIN delimiter line
        let cleaned = ep.replace(/^-----BEGIN[^\n]*\n/gm, '');
        // Remove END delimiter line
        cleaned = cleaned.replace(/-----END[^\n]*$/gm, '');
        // Remove header metadata (lines starting with common metadata patterns)
        cleaned = cleaned.replace(/^(Episode|Date|Duration|Host|Guest):[^\n]*\n/gim, '');
        return cleaned;
      }).join(' ')
    : rawData;

  // ============================================================================
  // STEP 2: HTML/XML TAG STRIPPING
  // ============================================================================
  
  // Remove all HTML/XML-like tags including <time>, <cite>, <p>, etc.
  // This regex matches opening tags, closing tags, and self-closing tags
  concatenatedText = concatenatedText.replace(/<[^>]+>/g, '');
  
  // ============================================================================
  // STEP 3: HTML ENTITY NORMALIZATION
  // ============================================================================
  
  const htmlEntities = {
    '&#39;': "'",
    '&quot;': '"',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
    '&mdash;': '—',
    '&ndash;': '–',
    '&ldquo;': '"',
    '&rdquo;': '"',
    '&lsquo;': "'",
    '&rsquo;': "'",
    '&hellip;': '...',
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™'
  };
  
  // Replace all HTML entities
  Object.entries(htmlEntities).forEach(([entity, char]) => {
    concatenatedText = concatenatedText.split(entity).join(char);
  });
  
  // Handle numeric HTML entities (&#NNNN;)
  concatenatedText = concatenatedText.replace(/&#(\d+);/g, (match, dec) => {
    return String.fromCharCode(parseInt(dec, 10));
  });
  
  // Handle hex HTML entities (&#xHHHH;)
  concatenatedText = concatenatedText.replace(/&#x([0-9a-f]+);/gi, (match, hex) => {
    return String.fromCharCode(parseInt(hex, 16));
  });
  
  // ============================================================================
  // STEP 4: WHITESPACE CLEANUP
  // ============================================================================
  
  // Replace all newlines and carriage returns with single space
  concatenatedText = concatenatedText.replace(/[\r\n]+/g, ' ');
  
  // Replace multiple consecutive spaces with single space
  concatenatedText = concatenatedText.replace(/\s{2,}/g, ' ');
  
  // Trim leading and trailing whitespace
  concatenatedText = concatenatedText.trim();
  
  // Final validation after cleaning
  if (!concatenatedText || concatenatedText.length === 0) {
    throw new Error('Cleaned text is empty - input may contain only metadata/tags');
  }
  
  // ============================================================================
  // STEP 5: CONTEXTUAL CHUNKING AT SENTENCE BOUNDARIES
  // ============================================================================
  
  const TARGET_CHUNK_SIZE = 400;
  const MAX_CHUNK_SIZE = 500;
  const chunks = [];
  
  // Split text into sentences (periods followed by space and capital letter)
  // This regex handles: ". A", "! B", "? C" while avoiding "Dr.", "Mr.", etc.
  const sentencePattern = /(?<=[.!?])\s+(?=[A-Z])/;
  const sentences = concatenatedText.split(sentencePattern);
  
  let currentChunk = '';
  
  for (let i = 0; i < sentences.length; i++) {
    const sentence = sentences[i].trim();
    
    if (!sentence) continue;
    
    // Check if adding this sentence would exceed MAX_CHUNK_SIZE
    const potentialLength = currentChunk.length + sentence.length + (currentChunk ? 1 : 0);
    
    if (currentChunk && potentialLength > MAX_CHUNK_SIZE) {
      // Current chunk is complete, save it
      chunks.push(currentChunk.trim());
      currentChunk = sentence;
    } else if (currentChunk && potentialLength > TARGET_CHUNK_SIZE) {
      // We've reached target size, check if we should start new chunk
      // Only start new chunk if current chunk is substantial (>200 chars)
      if (currentChunk.length > 200) {
        chunks.push(currentChunk.trim());
        currentChunk = sentence;
      } else {
        // Current chunk too small, add this sentence even if it exceeds target
        currentChunk += (currentChunk ? ' ' : '') + sentence;
      }
    } else {
      // Add sentence to current chunk
      currentChunk += (currentChunk ? ' ' : '') + sentence;
    }
  }
  
  // Add final chunk if it exists
  if (currentChunk.trim()) {
    chunks.push(currentChunk.trim());
  }
  
  // Edge case: if no chunks created, create one from entire text
  if (chunks.length === 0 && concatenatedText.trim()) {
    // If text is longer than MAX_CHUNK_SIZE, split it at word boundaries
    if (concatenatedText.length > MAX_CHUNK_SIZE) {
      const words = concatenatedText.split(/\s+/);
      let chunk = '';
      
      for (const word of words) {
        if ((chunk + ' ' + word).length > MAX_CHUNK_SIZE && chunk) {
          chunks.push(chunk.trim());
          chunk = word;
        } else {
          chunk += (chunk ? ' ' : '') + word;
        }
      }
      
      if (chunk.trim()) {
        chunks.push(chunk.trim());
      }
    } else {
      chunks.push(concatenatedText.trim());
    }
  }
  
  // ============================================================================
  // STEP 6: FORMAT OUTPUT FOR n8n
  // ============================================================================
  
  // Convert chunks to n8n item format
  const outputItems = chunks.map((chunk, index) => ({
    json: {
      text_chunk: chunk,
      chunk_index: index,
      chunk_length: chunk.length,
      total_chunks: chunks.length
    }
  }));
  
  // Log processing stats
  console.log(`Transcript Processing Complete:
    - Input length: ${rawData.length} characters
    - Cleaned length: ${concatenatedText.length} characters
    - Total chunks: ${chunks.length}
    - Avg chunk size: ${Math.round(chunks.reduce((sum, c) => sum + c.length, 0) / chunks.length)} chars
    - Min chunk size: ${Math.min(...chunks.map(c => c.length))} chars
    - Max chunk size: ${Math.max(...chunks.map(c => c.length))} chars
  `);
  
  return outputItems;
  
} catch (error) {
  // Error handling - return error as n8n item for debugging
  console.error('Transcript cleaning error:', error);
  
  return [{
    json: {
      error: true,
      error_message: error.message,
      error_stack: error.stack,
      text_chunk: null
    }
  }];
}