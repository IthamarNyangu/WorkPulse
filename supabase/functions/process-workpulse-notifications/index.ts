import { createClient } from 'npm:@supabase/supabase-js@2'

type NotificationRow = {
  id: string
  user_id: string
  title: string
  message: string
  action_label: string | null
  navigation_target: string | null
}

type ServiceAccount = {
  client_email: string
  private_key: string
  project_id: string
}

const jsonHeaders = { 'Content-Type': 'application/json' }

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const expectedSecret = Deno.env.get('WORKPULSE_CRON_SECRET')
  if (!expectedSecret || request.headers.get('x-workpulse-cron-secret') !== expectedSecret) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
  const serviceAccount = JSON.parse(
    Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!,
  ) as ServiceAccount

  const { error: generationError } = await supabase.rpc(
    'generate_scheduled_attendance_reminders',
  )
  if (generationError) {
    console.error('Reminder generation failed', generationError)
  }

  const { data, error: claimError } = await supabase.rpc(
    'claim_pending_push_notifications',
    { p_limit: 100 },
  )
  if (claimError) {
    return Response.json({ error: claimError.message }, { status: 500 })
  }

  const notifications = (data ?? []) as NotificationRow[]
  if (notifications.length === 0) {
    return Response.json({ generated: !generationError, claimed: 0, sent: 0 })
  }

  const accessToken = await googleAccessToken(serviceAccount)
  let sent = 0

  for (const notification of notifications) {
    const { data: tokenRows, error: tokenError } = await supabase
      .from('device_tokens')
      .select('id, token')
      .eq('user_id', notification.user_id)
      .eq('is_active', true)

    if (tokenError || !tokenRows || tokenRows.length === 0) {
      await releaseClaim(
        supabase,
        notification.id,
        tokenError?.message ?? 'No active device token is registered.',
      )
      continue
    }

    let delivered = false
    const errors: string[] = []
    for (const tokenRow of tokenRows) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            ...jsonHeaders,
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: tokenRow.token,
              notification: {
                title: notification.title,
                body: notification.message,
              },
              data: {
                notification_id: notification.id,
                navigation_target: notification.navigation_target ?? '',
                action_label: notification.action_label ?? '',
                title: notification.title,
                message: notification.message,
              },
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'workpulse_reminders',
                },
              },
            },
          }),
        },
      )

      if (response.ok) {
        delivered = true
        continue
      }

      const responseText = await response.text()
      errors.push(`${response.status}: ${responseText}`)
      if (response.status === 404 || responseText.includes('UNREGISTERED')) {
        await supabase
          .from('device_tokens')
          .update({ is_active: false, updated_at: new Date().toISOString() })
          .eq('id', tokenRow.id)
      }
    }

    if (delivered) {
      sent++
      await supabase
        .from('notifications')
        .update({
          push_sent_at: new Date().toISOString(),
          push_claimed_at: null,
          push_last_error: errors.length === 0 ? null : errors.join('\n').slice(0, 2000),
        })
        .eq('id', notification.id)
    } else {
      await releaseClaim(
        supabase,
        notification.id,
        errors.join('\n').slice(0, 2000) || 'FCM delivery failed.',
      )
    }
  }

  return Response.json({
    generated: !generationError,
    claimed: notifications.length,
    sent,
  })
})

async function releaseClaim(
  supabase: ReturnType<typeof createClient>,
  notificationId: string,
  error: string,
) {
  await supabase
    .from('notifications')
    .update({ push_claimed_at: null, push_last_error: error })
    .eq('id', notificationId)
}

async function googleAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const assertion = await signJwt(
    {
      alg: 'RS256',
      typ: 'JWT',
    },
    {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    serviceAccount.private_key,
  )

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  const body = await response.json()
  if (!response.ok || !body.access_token) {
    throw new Error(`Unable to create an FCM access token: ${JSON.stringify(body)}`)
  }
  return body.access_token as string
}

async function signJwt(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const encodedHeader = base64Url(new TextEncoder().encode(JSON.stringify(header)))
  const encodedPayload = base64Url(new TextEncoder().encode(JSON.stringify(payload)))
  const unsigned = `${encodedHeader}.${encodedPayload}`
  const keyBytes = pemBytes(privateKeyPem)
  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  return `${unsigned}.${base64Url(new Uint8Array(signature))}`
}

function pemBytes(pem: string): Uint8Array {
  const value = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0))
}

function base64Url(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}
