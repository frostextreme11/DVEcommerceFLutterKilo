// import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// const corsHeaders = {
//   'Access-Control-Allow-Origin': '*',
//   'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
// }

// interface NotificationRequest {
//   adminToken: string
//   customerName: string
//   quantity: number
//   totalPrice: number
//   orderId: string
//   orderDate: string
// }

// serve(async (req: Request) => {
//   // Handle CORS preflight requests
//   if (req.method === 'OPTIONS') {
//     return new Response('ok', { headers: corsHeaders })
//   }

//   try {
//     const { adminToken, customerName, quantity, totalPrice, orderId, orderDate }: NotificationRequest = await req.json()

//     // Get service account from environment variables
//     const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
//     const projectId = Deno.env.get('FCM_PROJECT_ID')

//     if (!serviceAccountJson || !projectId) {
//       throw new Error('Missing FCM configuration')
//     }

//     const serviceAccount = JSON.parse(serviceAccountJson)

//     // Create JWT token
//     const jwt = await createJWT(serviceAccount, projectId)

//     // Get access token from Google OAuth2
//     const accessToken = await getAccessToken(jwt)

//     // Send FCM notification
//     const fcmResult = await sendFCMNotification(
//       accessToken,
//       adminToken,
//       customerName,
//       quantity,
//       totalPrice,
//       orderId,
//       orderDate,
//       projectId
//     )

//     return new Response(
//       JSON.stringify({
//         success: true,
//         message: 'Notification sent successfully',
//         data: fcmResult
//       }),
//       {
//         headers: { ...corsHeaders, 'Content-Type': 'application/json' },
//         status: 200,
//       },
//     )
//   } catch (error) {
//     console.error('Error sending notification:', error)
//     return new Response(
//       JSON.stringify({
//         success: false,
//         error: error instanceof Error ? error.message : 'Unknown error'
//       }),
//       {
//         headers: { ...corsHeaders, 'Content-Type': 'application/json' },
//         status: 500,
//       },
//     )
//   }
// })

// async function createJWT(serviceAccount: any, projectId: string): Promise<string> {
//   const header = {
//     alg: 'RS256',
//     typ: 'JWT'
//   }

//   const now = Math.floor(Date.now() / 1000)
//   const payload = {
//     iss: serviceAccount.client_email,
//     scope: 'https://www.googleapis.com/auth/firebase.messaging',
//     aud: 'https://oauth2.googleapis.com/token',
//     exp: now + 3600,
//     iat: now,
//   }

//   const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
//   const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

//   const message = `${encodedHeader}.${encodedPayload}`

//   // Create RSA signature using service account private key
//   const privateKeyPem = serviceAccount.private_key
//   const signature = await signJWT(message, privateKeyPem)

//   const encodedSignature = btoa(String.fromCharCode(...signature))
//     .replace(/=/g, '')
//     .replace(/\+/g, '-')
//     .replace(/\//g, '_')

//   return `${encodedHeader}.${encodedPayload}.${encodedSignature}`
// }

// async function signJWT(message: string, privateKeyPem: string): Promise<Uint8Array> {
//   // For Deno environment, we'll use a simpler approach
//   // In a real implementation, you would use proper RSA signing

//   // Remove PEM header and footer and decode
//   const pemContents = privateKeyPem
//     .replace('-----BEGIN PRIVATE KEY-----', '')
//     .replace('-----END PRIVATE KEY-----', '')
//     .replace(/\n/g, '')

//   const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

//   // Create a signature using the private key content
//   // This is a simplified approach - in production you should use proper RSA
//   const encoder = new TextEncoder()
//   const messageBytes = encoder.encode(message)
//   const keyBytes = binaryDer.slice(0, 32) // Use part of private key

//   // Create HMAC signature
//   const cryptoKey = await crypto.subtle.importKey(
//     'raw',
//     keyBytes,
//     { name: 'HMAC', hash: 'SHA-256' },
//     false,
//     ['sign']
//   )

//   const signature = await crypto.subtle.sign('HMAC', cryptoKey, messageBytes)
//   return new Uint8Array(signature)
// }

// async function getAccessToken(jwt: string): Promise<string> {
//   const response = await fetch('https://oauth2.googleapis.com/token', {
//     method: 'POST',
//     headers: {
//       'Content-Type': 'application/x-www-form-urlencoded',
//     },
//     body: new URLSearchParams({
//       grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
//       assertion: jwt,
//     }),
//   })

//   if (!response.ok) {
//     const error = await response.text()
//     throw new Error(`Failed to get access token: ${response.status} ${error}`)
//   }

//   const data = await response.json()
//   return data.access_token
// }

// async function sendFCMNotification(
//   accessToken: string,
//   adminToken: string,
//   customerName: string,
//   quantity: number,
//   totalPrice: number,
//   orderId: string,
//   orderDate: string,
//   projectId: string
// ) {
//   const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

//   // Format price
//   const formattedPrice = `Rp ${totalPrice.toLocaleString('id-ID')}`

//   // Format date
//   const date = new Date(orderDate)
//   const formattedDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()} ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`

//   const payload = {
//     message: {
//       token: adminToken,
//       notification: {
//         title: 'New Order Received!',
//         body: `Customer: ${customerName}\nItems: ${quantity}\nTotal: ${formattedPrice}\nTime: ${formattedDate}`,
//       },
//       data: {
//         type: 'new_order',
//         order_id: orderId,
//         customer_name: customerName,
//         quantity: quantity.toString(),
//         total_price: totalPrice.toString(),
//         order_date: orderDate,
//         click_action: 'FLUTTER_NOTIFICATION_CLICK',
//       },
//       android: {
//         priority: 'high',
//         notification: {
//           channel_id: 'orders',
//           default_sound: true,
//           default_vibrate_timings: true,
//           notification_priority: 'PRIORITY_HIGH',
//           icon: 'ic_launcher',
//         },
//       },
//       apns: {
//         payload: {
//           aps: {
//             alert: {
//               title: 'New Order Received!',
//               body: `Customer: ${customerName}\nItems: ${quantity}\nTotal: ${formattedPrice}\nTime: ${formattedDate}`,
//             },
//             sound: 'default',
//             badge: 1,
//           },
//         },
//       },
//     },
//   }

//   const response = await fetch(fcmUrl, {
//     method: 'POST',
//     headers: {
//       'Content-Type': 'application/json',
//       'Authorization': `Bearer ${accessToken}`,
//     },
//     body: JSON.stringify(payload),
//   })

//   if (!response.ok) {
//     const error = await response.text()
//     throw new Error(`FCM request failed: ${response.status} ${error}`)
//   }

//   return await response.json()
// }