import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  adminToken: string
  customerName: string
  quantity: number
  totalPrice: number
  orderId: string
  orderDate: string
}

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { token, title, body, data }: { token: string; title: string; body: string; data: any } = await req.json()

    console.log('=== SUPABASE EDGE FUNCTION DEBUG ===')
    console.log('Received request:', {
      token: token ? token.substring(0, 20) + '...' : 'null',
      title,
      body,
      data
    })

    // Get service account from environment variables
    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
    const projectId = Deno.env.get('FCM_PROJECT_ID')

    if (!serviceAccountJson || !projectId) {
      console.error('Missing FCM configuration')
      throw new Error('Missing FCM configuration')
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    console.log('Service account loaded for project:', projectId)

    // Create JWT token
    const jwt = await createJWT(serviceAccount, projectId)
    console.log('JWT token created')

    // Get access token from Google OAuth2
    const accessToken = await getAccessToken(jwt)
    console.log('Access token obtained')

    // Send FCM notification
    const fcmResult = await sendFCMNotification(
      accessToken,
      token,
      title,
      body,
      data,
      projectId
    )

    console.log('FCM result:', fcmResult)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Notification sent successfully',
        data: fcmResult
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})

async function createJWT(serviceAccount: any, projectId: string): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  }

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }

  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const message = `${encodedHeader}.${encodedPayload}`

  // Create RSA signature using service account private key
  const privateKeyPem = serviceAccount.private_key
  const signature = await signJWT(message, privateKeyPem)

  const encodedSignature = btoa(String.fromCharCode(...signature))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')

  return `${encodedHeader}.${encodedPayload}.${encodedSignature}`
}

async function signJWT(message: string, privateKeyPem: string): Promise<Uint8Array> {
  // Remove PEM header and footer and decode base64
  const pemContents = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\n/g, '')

  // Convert base64 to binary DER format
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  // Import the private key for RSA signing
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  // Create the signature
  const encoder = new TextEncoder()
  const messageBytes = encoder.encode(message)
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    messageBytes
  )

  return new Uint8Array(signature)
}

async function getAccessToken(jwt: string): Promise<string> {
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Failed to get access token: ${response.status} ${error}`)
  }

  const data = await response.json()
  return data.access_token
}

async function sendFCMNotification(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: any,
  projectId: string
) {
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

  console.log('Sending FCM notification to:', token.substring(0, 20) + '...')
  console.log('Title:', title)
  console.log('Body:', body)

  const payload = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data,
      android: {
        priority: 'high',
        notification: {
          channel_id: 'orders',
          default_sound: true,
          default_vibrate_timings: true,
          notification_priority: 'PRIORITY_HIGH',
          icon: 'ic_launcher',
          color: '#FF0000',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    },
  }

  console.log('FCM Payload:', JSON.stringify(payload, null, 2))

  const response = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    },
    body: JSON.stringify(payload),
  })

  console.log('FCM Response status:', response.status)

  if (!response.ok) {
    const error = await response.text()
    console.error('FCM request failed:', error)
    throw new Error(`FCM request failed: ${response.status} ${error}`)
  }

  const result = await response.json()
  console.log('FCM result:', result)
  return result
}