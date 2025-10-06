/**
 * CONTENT-TYPE SPECIFIC CHUNKING STRATEGIES
 * Optimized for semantic coherence and search performance
 * Target: 90%+ search accuracy with <250ms response times
 */

class ContentChunker {
    constructor() {
        this.MAX_CHUNK_SIZE = {
            podcast: 1500,    // Conversational flow units
            book: 1200,       // Paragraph/concept units  
            avatar: 800,      // Trait/behavior units
            social: 600,      // Campaign/post units
            prompt: 400       // Instruction units
        };
        
        this.OVERLAP_SIZE = {
            podcast: 200,     // Speaker transitions
            book: 150,        // Concept continuity
            avatar: 100,      // Trait relationships
            social: 75,       // Message coherence
            prompt: 50        // Instruction clarity
        };
    }

    /**
     * PODCAST TRANSCRIPT CHUNKING
     * Optimized for: Speaker changes, timestamps, natural conversation flow
     */
    chunkPodcastTranscript(transcript, metadata = {}) {
        const chunks = [];
        let currentChunk = '';
        let currentSpeaker = null;
        let chunkStart = 0;
        let chunkIndex = 0;

        // Parse transcript with speaker detection
        const segments = this.parseTranscriptSegments(transcript);
        
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
            const segmentText = `[${segment.timestamp}] ${segment.speaker}: ${segment.text}`;
            
            // Check if adding this segment exceeds chunk size
            if (currentChunk.length + segmentText.length > this.MAX_CHUNK_SIZE.podcast) {
                if (currentChunk.length > 0) {
                    chunks.push(this.createPodcastChunk(
                        currentChunk, 
                        chunkIndex++, 
                        chunkStart, 
                        segment.timestamp, 
                        currentSpeaker,
                        metadata
                    ));
                    
                    // Start new chunk with overlap
                    currentChunk = this.getOverlapText(currentChunk, this.OVERLAP_SIZE.podcast);
                }
                chunkStart = segment.timestamp;
            }
            
            currentChunk += (currentChunk ? '\n' : '') + segmentText;
            currentSpeaker = segment.speaker;
        }
        
        // Add final chunk
        if (currentChunk.length > 0) {
            chunks.push(this.createPodcastChunk(
                currentChunk, 
                chunkIndex, 
                chunkStart, 
                segments[segments.length - 1].timestamp, 
                currentSpeaker,
                metadata
            ));
        }
        
        return this.finalizePodcastChunks(chunks);
    }

    /**
     * BOOK CONTENT CHUNKING  
     * Optimized for: Chapters, concepts, hierarchical structure
     */
    chunkBookContent(content, bookMetadata = {}) {
        const chunks = [];
        let chunkIndex = 0;
        
        // First, split by chapters if available
        const chapters = this.extractChapters(content, bookMetadata);
        
        for (const chapter of chapters) {
            const chapterChunks = this.chunkBySemanticUnits(
                chapter.content,
                this.MAX_CHUNK_SIZE.book,
                this.OVERLAP_SIZE.book,
                {
                    contentType: 'book',
                    chapterTitle: chapter.title,
                    chapterNumber: chapter.number,
                    sectionType: 'chapter',
                    ...bookMetadata
                }
            );
            
            chapterChunks.forEach(chunk => {
                chunk.chunkIndex = chunkIndex++;
                chunks.push(chunk);
            });
        }
        
        return this.finalizeBookChunks(chunks);
    }

    /**
     * AVATAR PERSONALITY CHUNKING
     * Optimized for: Traits, behaviors, response patterns
     */
    chunkAvatarData(avatarData) {
        const chunks = [];
        let chunkIndex = 0;
        
        // Core personality chunk
        if (avatarData.description || avatarData.personalityTraits) {
            chunks.push({
                chunkIndex: chunkIndex++,
                chunkText: this.buildAvatarPersonalityChunk(avatarData),
                sectionType: 'personality',
                importanceScore: 10, // Highest importance
                metadata: {
                    contentType: 'avatar',
                    section: 'core_personality'
                }
            });
        }
        
        // Expertise chunks
        if (avatarData.expertiseAreas && avatarData.expertiseAreas.length > 0) {
            const expertiseChunks = this.chunkAvatarExpertise(avatarData.expertiseAreas, avatarData.name);
            expertiseChunks.forEach(chunk => {
                chunk.chunkIndex = chunkIndex++;
                chunks.push(chunk);
            });
        }
        
        // Communication style chunk
        if (avatarData.communicationStyle || avatarData.promptTemplate) {
            chunks.push({
                chunkIndex: chunkIndex++,
                chunkText: this.buildAvatarStyleChunk(avatarData),
                sectionType: 'communication',
                importanceScore: 9,
                metadata: {
                    contentType: 'avatar',
                    section: 'communication_style'
                }
            });
        }
        
        // Example responses chunks
        if (avatarData.exampleResponses && avatarData.exampleResponses.length > 0) {
            const exampleChunks = this.chunkAvatarExamples(avatarData.exampleResponses, avatarData.name);
            exampleChunks.forEach(chunk => {
                chunk.chunkIndex = chunkIndex++;
                chunks.push(chunk);
            });
        }
        
        return this.finalizeAvatarChunks(chunks, avatarData.name);
    }

    /**
     * SOCIAL MEDIA PLAN CHUNKING
     * Optimized for: Campaigns, platforms, content pillars
     */
    chunkSocialPlan(socialPlan) {
        const chunks = [];
        let chunkIndex = 0;
        
        // Campaign overview chunk
        chunks.push({
            chunkIndex: chunkIndex++,
            chunkText: this.buildCampaignOverviewChunk(socialPlan),
            sectionType: 'overview',
            importanceScore: 9,
            metadata: {
                contentType: 'social',
                platform: socialPlan.platform,
                campaignName: socialPlan.campaignName
            }
        });
        
        // Content strategy chunks
        if (socialPlan.contentPillars && socialPlan.contentPillars.length > 0) {
            const pillarChunks = this.chunkContentPillars(socialPlan.contentPillars, socialPlan);
            pillarChunks.forEach(chunk => {
                chunk.chunkIndex = chunkIndex++;
                chunks.push(chunk);
            });
        }
        
        // Audience and messaging chunk
        chunks.push({
            chunkIndex: chunkIndex++,
            chunkText: this.buildAudienceMessagingChunk(socialPlan),
            sectionType: 'audience',
            importanceScore: 8,
            metadata: {
                contentType: 'social',
                platform: socialPlan.platform,
                section: 'targeting'
            }
        });
        
        return this.finalizeSocialChunks(chunks, socialPlan);
    }

    /**
     * PROMPT TEMPLATE CHUNKING
     * Optimized for: Instructions, examples, parameters
     */
    chunkPromptTemplate(promptData) {
        const chunks = [];
        let chunkIndex = 0;
        
        // Core instruction chunk
        chunks.push({
            chunkIndex: chunkIndex++,
            chunkText: this.buildPromptInstructionChunk(promptData),
            sectionType: 'instruction',
            importanceScore: 10,
            metadata: {
                contentType: 'prompt',
                category: promptData.category,
                useCase: promptData.useCase
            }
        });
        
        // Examples chunk (if exists and substantial)
        if (promptData.examples && promptData.examples.length > 0) {
            const exampleText = this.buildPromptExamplesChunk(promptData.examples);
            if (exampleText.length > 100) { // Only create if substantial
                chunks.push({
                    chunkIndex: chunkIndex++,
                    chunkText: exampleText,
                    sectionType: 'examples',
                    importanceScore: 8,
                    metadata: {
                        contentType: 'prompt',
                        section: 'examples',
                        exampleCount: promptData.examples.length
                    }
                });
            }
        }
        
        // Parameters and config chunk
        if (promptData.parameters || promptData.modelConfig) {
            chunks.push({
                chunkIndex: chunkIndex++,
                chunkText: this.buildPromptConfigChunk(promptData),
                sectionType: 'configuration',
                importanceScore: 7,
                metadata: {
                    contentType: 'prompt',
                    section: 'configuration'
                }
            });
        }
        
        return this.finalizePromptChunks(chunks, promptData);
    }

    // =====================================================================
    // HELPER METHODS
    // =====================================================================

    parseTranscriptSegments(transcript) {
        // Parse transcript format: [00:12:34] Speaker: Text
        const segments = [];
        const lines = transcript.split('\n');
        
        for (const line of lines) {
            const match = line.match(/\[(\d{2}:\d{2}:\d{2})\]\s*([^:]+):\s*(.+)/);
            if (match) {
                segments.push({
                    timestamp: match[1],
                    speaker: match[2].trim(),
                    text: match[3].trim()
                });
            }
        }
        
        return segments;
    }

    chunkBySemanticUnits(text, maxSize, overlapSize, metadata = {}) {
        const chunks = [];
        const sentences = this.splitIntoSentences(text);
        let currentChunk = '';
        let chunkIndex = 0;
        
        for (const sentence of sentences) {
            if (currentChunk.length + sentence.length > maxSize && currentChunk.length > 0) {
                chunks.push({
                    chunkIndex: chunkIndex++,
                    chunkText: currentChunk.trim(),
                    chunkSize: currentChunk.length,
                    overlapSize: overlapSize,
                    ...metadata
                });
                
                // Start new chunk with overlap
                currentChunk = this.getOverlapText(currentChunk, overlapSize) + ' ';
            }
            
            currentChunk += sentence + ' ';
        }
        
        if (currentChunk.trim().length > 0) {
            chunks.push({
                chunkIndex: chunkIndex,
                chunkText: currentChunk.trim(),
                chunkSize: currentChunk.length,
                overlapSize: overlapSize,
                ...metadata
            });
        }
        
        return chunks;
    }

    splitIntoSentences(text) {
        // Enhanced sentence splitting that preserves meaning
        return text.match(/[^\.!?]+[\.!?]+/g) || [text];
    }

    getOverlapText(text, overlapSize) {
        if (text.length <= overlapSize) return text;
        
        // Find the last sentence boundary within overlap size
        const overlap = text.slice(-overlapSize);
        const lastSentence = overlap.lastIndexOf('.');
        
        if (lastSentence > overlapSize * 0.5) {
            return text.slice(-(overlapSize - lastSentence));
        }
        
        return text.slice(-overlapSize);
    }

    // Content-specific chunk builders
    createPodcastChunk(text, index, startTime, endTime, speaker, metadata) {
        return {
            chunkIndex: index,
            chunkText: text,
            chunkSize: text.length,
            timestampStart: this.timeToSeconds(startTime),
            timestampEnd: this.timeToSeconds(endTime),
            speaker: speaker,
            sectionType: 'conversation',
            importanceScore: this.calculatePodcastImportance(text, speaker),
            metadata: {
                contentType: 'podcast',
                duration: this.timeToSeconds(endTime) - this.timeToSeconds(startTime),
                ...metadata
            }
        };
    }

    buildAvatarPersonalityChunk(avatarData) {
        const parts = [];
        
        if (avatarData.description) {
            parts.push(`Description: ${avatarData.description}`);
        }
        
        if (avatarData.personalityTraits && avatarData.personalityTraits.length > 0) {
            parts.push(`Personality Traits: ${avatarData.personalityTraits.join(', ')}`);
        }
        
        if (avatarData.values && avatarData.values.length > 0) {
            parts.push(`Core Values: ${avatarData.values.join(', ')}`);
        }
        
        if (avatarData.backgroundStory) {
            parts.push(`Background: ${avatarData.backgroundStory}`);
        }
        
        return parts.join('\n\n');
    }

    calculatePodcastImportance(text, speaker) {
        // Higher importance for key speakers, questions, important topics
        let score = 5.0; // Base score
        
        if (speaker && speaker.toLowerCase().includes('host')) score += 1.0;
        if (text.includes('?')) score += 0.5; // Questions are important
        if (text.match(/\b(important|key|crucial|significant)\b/i)) score += 1.0;
        
        return Math.min(10.0, score);
    }

    timeToSeconds(timeStr) {
        const parts = timeStr.split(':').map(Number);
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }

    // Finalization methods that add total_chunks to all chunks
    finalizePodcastChunks(chunks) {
        const totalChunks = chunks.length;
        return chunks.map(chunk => ({ ...chunk, totalChunks }));
    }

    finalizeBookChunks(chunks) {
        const totalChunks = chunks.length;
        return chunks.map(chunk => ({ ...chunk, totalChunks }));
    }

    finalizeAvatarChunks(chunks, avatarName) {
        const totalChunks = chunks.length;
        return chunks.map(chunk => ({ 
            ...chunk, 
            totalChunks,
            namedEntities: [avatarName]
        }));
    }

    finalizeSocialChunks(chunks, socialPlan) {
        const totalChunks = chunks.length;
        return chunks.map(chunk => ({ 
            ...chunk, 
            totalChunks,
            namedEntities: [socialPlan.campaignName, socialPlan.platform]
        }));
    }

    finalizePromptChunks(chunks, promptData) {
        const totalChunks = chunks.length;
        return chunks.map(chunk => ({ 
            ...chunk, 
            totalChunks,
            namedEntities: [promptData.name, promptData.category]
        }));
    }
}

// =====================================================================
// EXPORT FOR N8N USAGE
// =====================================================================

module.exports = { ContentChunker };

// Usage example for n8n:
// const { ContentChunker } = require('./chunking-strategies.js');
// const chunker = new ContentChunker();
// const chunks = chunker.chunkPodcastTranscript(transcript, metadata);