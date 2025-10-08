import { NextRequest, NextResponse } from 'next/server';

/**
 * Proxy route for document upload webhook
 * Forwards requests from Vercel UI to n8n webhook on DigitalOcean
 *
 * Architecture:
 * Vercel (ui-theta-black.vercel.app)
 *   → /api/webhook/documents (this proxy)
 *   → https://ai.thirdeyediagnostics.com/webhook/documents (n8n)
 */

/**
 * Get the n8n webhook URL from environment variables
 * Priority: N8N_DOCUMENTS_WEBHOOK_URL > NEXT_PUBLIC_N8N_URL + /webhook/documents
 */
function getWebhookUrl(): string | null {
  const directUrl = process.env.N8N_DOCUMENTS_WEBHOOK_URL;
  if (directUrl) return directUrl;
  
  const baseUrl = process.env.NEXT_PUBLIC_N8N_URL;
  if (baseUrl) {
    // Remove trailing slash if present
    const cleanBase = baseUrl.replace(/\/$/, '');
    return `${cleanBase}/webhook/documents`;
  }
  
  return null;
}

export async function POST(request: NextRequest): Promise<NextResponse> {
  try {
    const n8nWebhookUrl = getWebhookUrl();
    
    if (!n8nWebhookUrl) {
      console.error('[Webhook Proxy] Configuration error: N8N_DOCUMENTS_WEBHOOK_URL or NEXT_PUBLIC_N8N_URL must be set');
      return NextResponse.json(
        {
          status: 'error',
          message: 'Webhook configuration error - contact administrator',
          details: 'N8N_DOCUMENTS_WEBHOOK_URL environment variable not set in Vercel'
        },
        { status: 500 }
      );
    }

    // Get the request body
    const body = await request.json();
    
    console.log('[Webhook Proxy] Forwarding document to n8n:', {
      url: n8nWebhookUrl,
      filename: body.filename,
      size: body.size,
      type: body.type,
      timestamp: new Date().toISOString()
    });

    // Forward the request to n8n with timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30s timeout

    try {
      const response = await fetch(n8nWebhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'idudesRAG-Vercel-Proxy/1.0',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      // Get the response from n8n
      const responseData = await response.json();
      
      if (!response.ok) {
        console.error('[Webhook Proxy] n8n webhook error:', {
          status: response.status,
          statusText: response.statusText,
          data: responseData
        });
        
        return NextResponse.json(
          {
            status: 'error',
            message: responseData.message || 'Document processing failed in n8n workflow'
          },
          { status: response.status }
        );
      }

      console.log('[Webhook Proxy] Document upload successful:', {
        filename: body.filename,
        response: responseData
      });
      
      // Return the n8n response to the UI
      return NextResponse.json(responseData, { status: 200 });
      
    } catch (fetchError) {
      clearTimeout(timeoutId);
      
      if (fetchError instanceof Error && fetchError.name === 'AbortError') {
        console.error('[Webhook Proxy] Request timeout after 30s');
        return NextResponse.json(
          {
            status: 'error',
            message: 'Request timeout - n8n took too long to respond'
          },
          { status: 504 }
        );
      }
      throw fetchError;
    }
    
  } catch (error) {
    console.error('[Webhook Proxy] Unexpected error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    
    return NextResponse.json(
      {
        status: 'error',
        message: 'Internal server error during document upload',
        details: errorMessage
      },
      { status: 500 }
    );
  }
}

/**
 * Health check endpoint
 * GET /api/webhook/documents
 */
export async function GET(): Promise<NextResponse> {
  const webhookUrl = getWebhookUrl();
  
  return NextResponse.json(
    {
      status: 'ok',
      configured: !!webhookUrl,
      webhookUrl: webhookUrl ? '***configured***' : null,
      message: webhookUrl
        ? 'Webhook proxy is ready'
        : 'Missing N8N_DOCUMENTS_WEBHOOK_URL or NEXT_PUBLIC_N8N_URL environment variable',
      timestamp: new Date().toISOString()
    },
    { status: webhookUrl ? 200 : 500 }
  );
}