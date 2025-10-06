import { NextRequest, NextResponse } from 'next/server'

export const maxDuration = 60
export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  try {
    const { messages, model = 'gpt-5-nano' } = await req.json()

    if (!messages || !Array.isArray(messages)) {
      return NextResponse.json({ error: 'Messages array required' }, { status: 400 })
    }

    // Call OpenAI API with GPT-5-nano (cheapest model for search/classification)
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: model === 'gpt-5-nano' ? 'gpt-5-thinking-nano' : model,
        messages: [
          {
            role: 'system',
            content: `You are an AI assistant for Insurance Dudes document management system.
You have access to semantic search over uploaded documents.
Help users search documents, answer questions, and generate content.
Be concise and helpful.`
          },
          ...messages
        ],
        temperature: 0.7,
        max_tokens: 2000
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('OpenAI API error:', response.status, errorText)
      return NextResponse.json({
        error: 'AI request failed',
        details: `API returned ${response.status}`
      }, { status: 500 })
    }

    const data = await response.json()
    const assistantMessage = data.choices[0].message.content

    return NextResponse.json({
      success: true,
      message: assistantMessage,
      model: model,
      usage: data.usage
    })

  } catch (error) {
    console.error('Chat error:', error)
    return NextResponse.json({
      error: 'Chat failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 })
  }
}
