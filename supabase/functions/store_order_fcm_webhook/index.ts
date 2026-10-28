import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type StoreOrderEvent = {
  event: string;
  notification_id: string;
  order_store_part_id: string;
  order_id: string;
  store_id: string;
  order_number: string;
  recipient_user_id: string;
};

const encoder = new TextEncoder();

let cachedGoogleToken: string | null = null;
let cachedGoogleTokenExpiry = 0;

function jsonResponse(
  data: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function constantTimeEquals(left: string, right: string): boolean {
  const a = encoder.encode(left);
  const b = encoder.encode(right);

  if (a.length !== b.length) {
    return false;
  }

  let difference = 0;

  for (let i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }

  return difference === 0;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function decodeBase64(value: string): Uint8Array {
  return Uint8Array.from(atob(value), (character) =>
    character.charCodeAt(0)
  );
}

function getServiceRoleKey(): string | null {
  const legacyKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (legacyKey) {
    return legacyKey;
  }

  const packedKeys = Deno.env.get("SUPABASE_SECRET_KEYS");

  if (!packedKeys) {
    return null;
  }

  try {
    const keys = JSON.parse(packedKeys) as Record<string, unknown>;

    if (typeof keys.default === "string") {
      return keys.default;
    }
  } catch {
    return null;
  }

  return null;
}

function getFirebaseServiceAccount(): FirebaseServiceAccount {
  const encoded = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON_BASE64");

  if (!encoded) {
    throw new Error("Firebase service-account credentials are not configured.");
  }

  const account = JSON.parse(
    new TextDecoder().decode(decodeBase64(encoded)),
  ) as FirebaseServiceAccount;

  if (
    !account.project_id ||
    !account.client_email ||
    !account.private_key
  ) {
    throw new Error("Firebase service-account credentials are incomplete.");
  }

  return account;
}

async function getGoogleAccessToken(
  account: FirebaseServiceAccount,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  if (
    cachedGoogleToken &&
    cachedGoogleTokenExpiry > now + 60
  ) {
    return cachedGoogleToken;
  }

  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const header = base64UrlEncode(
    encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
  );

  const claims = base64UrlEncode(
    encoder.encode(
      JSON.stringify({
        iss: account.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: tokenUri,
        iat: now,
        exp: now + 3600,
      }),
    ),
  );

  const unsignedAssertion = `${header}.${claims}`;

  const pem = account.private_key
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    decodeBase64(pem),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      privateKey,
      encoder.encode(unsignedAssertion),
    ),
  );

  const assertion = `${unsignedAssertion}.${base64UrlEncode(signature)}`;

  const response = await fetch(tokenUri, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    console.error(
      "FCM OAuth token request failed:",
      response.status,
    );

    throw new Error("Could not obtain Firebase access token.");
  }

  const result = await response.json() as {
    access_token?: string;
    expires_in?: number;
  };

  if (!result.access_token) {
    throw new Error("Firebase did not return an access token.");
  }

  cachedGoogleToken = result.access_token;
  cachedGoogleTokenExpiry = now + (result.expires_in ?? 3600);

  return cachedGoogleToken;
}

async function sendPushNotification(
  account: FirebaseServiceAccount,
  accessToken: string,
  deviceToken: string,
  event: StoreOrderEvent,
): Promise<boolean> {
  const orderNumber =
    String(event.order_number ?? "").trim() ||
    event.order_id.substring(0, 8);

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: {
            title: "طلب جديد - هِنا",
            body: `لديك طلب جديد رقم ${orderNumber}`,
          },
          data: {
            type: "new_store_order",
            notification_id: event.notification_id,
            order_store_part_id: event.order_store_part_id,
            order_id: event.order_id,
            store_id: event.store_id,
            order_number: orderNumber,
          },
          android: {
            priority: "HIGH",
            notification: {
              sound: "default",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    console.warn(
      "FCM delivery failed:",
      response.status,
      "platform token omitted",
    );

    return false;
  }

  return true;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const expectedSecret = Deno.env.get("STORE_ORDER_FCM_WEBHOOK_SECRET");

  if (!expectedSecret) {
    console.error("Store-order webhook secret is not configured.");

    return jsonResponse({ error: "Webhook is not configured" }, 500);
  }

  const authorization = request.headers.get("Authorization") ?? "";

  if (!constantTimeEquals(authorization, `Bearer ${expectedSecret}`)) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let event: StoreOrderEvent;

  try {
    event = await request.json() as StoreOrderEvent;
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  if (
    event.event !== "new_store_order" ||
    !isUuid(event.notification_id) ||
    !isUuid(event.order_store_part_id) ||
    !isUuid(event.order_id) ||
    !isUuid(event.store_id) ||
    !isUuid(event.recipient_user_id)
  ) {
    return jsonResponse({ error: "Invalid store-order event" }, 400);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Supabase server credentials are unavailable.");
    }

    const account = getFirebaseServiceAccount();
    const accessToken = await getGoogleAccessToken(account);

    const tokenUrl = new URL(`${supabaseUrl}/rest/v1/user_fcm_tokens`);

    tokenUrl.searchParams.set("select", "fcm_token,platform");
    tokenUrl.searchParams.set(
      "user_id",
      `eq.${event.recipient_user_id}`,
    );
    tokenUrl.searchParams.set("platform", "in.(android,ios)");

    const tokenResponse = await fetch(tokenUrl, {
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    });

    if (!tokenResponse.ok) {
      console.error(
        "Could not retrieve recipient device tokens:",
        tokenResponse.status,
      );

      return jsonResponse({ error: "Could not retrieve device tokens" }, 502);
    }

    const devices = await tokenResponse.json() as Array<{
      fcm_token: string;
      platform: string;
    }>;

    if (!Array.isArray(devices) || devices.length === 0) {
      return jsonResponse({
        ok: true,
        sent: 0,
        failed: 0,
        reason: "no_registered_phone_devices",
      });
    }

    const results = await Promise.all(
      devices.map(async (device) => {
        try {
          return await sendPushNotification(
            account,
            accessToken,
            device.fcm_token,
            event,
          );
        } catch (error) {
          console.error(
            "FCM send operation failed:",
            error instanceof Error ? error.message : "Unknown error",
          );

          return false;
        }
      }),
    );

    const sent = results.filter(Boolean).length;
    const failed = results.length - sent;

    return jsonResponse({
      ok: failed === 0,
      sent,
      failed,
    }, failed > 0 && sent === 0 ? 502 : 200);
  } catch (error) {
    console.error(
      "Store-order push handler failed:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return jsonResponse({ error: "Push notification delivery failed" }, 500);
  }
});