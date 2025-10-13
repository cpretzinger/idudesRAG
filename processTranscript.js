const fs = require('fs');
const path = require('path');

/**
 * Cleans the podcast transcript content and chunks it into sentences.
 * @param {string} transcriptContent - The raw string content from the transcript file.
 * @returns {string[]} An array of sentences.
 */
function cleanAndChunkTranscript(transcriptContent) {
  // 1. Extract only the text within the <p> tags from the original content.
  // We are skipping the faulty step that deleted everything.
  const paragraphs = transcriptContent.match(/<p>(.*?)<\/p>/gs) || [];

  // 2. Clean and join the paragraphs
  const fullText = paragraphs
    // Remove the <p> and </p> tags themselves from each paragraph
    .map(p => p.replace(/<\/?p>/g, ''))
    // Replace HTML entities like &#39; with an apostrophe
    .map(p => p.replace(/&#39;/g, "'"))
    .join(' ') // Join all the text blocks into a single string
    .replace(/\s+/g, ' ') // Replace multiple whitespace chars with a single space
    .trim();

  // 3. Split the text into sentences
  const sentences = fullText.split(/(?<=[.!?])\s+/);

  // Filter out any empty strings that might result from the split
  return sentences.filter(sentence => sentence.length > 0);
}

// --- Main execution part of the script ---
const inputFileName = 'transcripts-pod.md';
const outputFileName = 'transcript_chunks.jsonl';

try {
  const fileContent = fs.readFileSync(path.join(__dirname, inputFileName), 'utf-8');
  const transcriptChunks = cleanAndChunkTranscript(fileContent);

  if (transcriptChunks.length === 0) {
    console.error("❌ Error: No text could be extracted from the <p> tags. Please check the input file format.");
    return;
  }

  // --- SAVE THE OUTPUT AS JSON LINES ---
  const jsonlData = transcriptChunks.map((chunkText, index) => {
    const chunkObject = {
      id: `chunk-${inputFileName}-${index + 1}`,
      text: chunkText,
      metadata: {
        source_file: inputFileName,
        chunk_number: index + 1
      }
    };
    return JSON.stringify(chunkObject);
  }).join('\n');

  fs.writeFileSync(path.join(__dirname, outputFileName), jsonlData);

  console.log(`✅ Successfully processed the transcript into ${transcriptChunks.length} chunks.`);
  console.log(`✅ Output saved to: ${outputFileName}`);

} catch (error) {
  if (error.code === 'ENOENT') {
    console.error(`❌ Error: The file '${inputFileName}' was not found.`);
  } else {
    console.error("An error occurred:", error);
  }
}