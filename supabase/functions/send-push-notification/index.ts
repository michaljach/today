import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") || "com.thisday.app";
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT") || "development"; // "development" or "production"

interface NotificationPayload {
  recipient_id: string;
  actor_id: string;
  type: "like" | "follow" | "comment";
  post_id?: string;
  comment_id?: string;
}

interface Profile {
  display_name: string;
  username: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    const payload: NotificationPayload = await req.json();
    
    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get device tokens for the recipient
    const { data: tokens, error: tokensError } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", payload.recipient_id)
      .eq("platform", "ios");

    if (tokensError || !tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No device tokens found" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get actor's profile for notification content
    const { data: actor, error: actorError } = await supabase
      .from("profiles")
      .select("display_name, username")
      .eq("id", payload.actor_id)
      .single();

    if (actorError || !actor) {
      return new Response(
        JSON.stringify({ error: "Actor not found" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Build notification content
    const { title, body } = buildNotificationContent(payload.type, actor);

    // Generate JWT for APNs
    const jwt = await generateAPNsJWT();

    // Send push to all device tokens
    const apnsHost = APNS_ENVIRONMENT === "production" 
      ? "api.push.apple.com" 
      : "api.sandbox.push.apple.com";

    const results = await Promise.allSettled(
      tokens.map((t) => sendAPNsPush(apnsHost, t.token, jwt, {
        title,
        body,
        type: payload.type,
        post_id: payload.post_id,
        actor_id: payload.actor_id,
      }))
    );

    const successCount = results.filter((r) => r.status === "fulfilled").length;
    const errors = results
      .filter((r): r is PromiseRejectedResult => r.status === "rejected")
      .map((r) => r.reason?.message || String(r.reason));

    console.log(`Push results: ${successCount}/${tokens.length} succeeded`);
    if (errors.length > 0) {
      console.log(`Push errors: ${JSON.stringify(errors)}`);
    }

    return new Response(
      JSON.stringify({ 
        message: `Sent ${successCount}/${tokens.length} push notifications`,
        errors: errors.length > 0 ? errors : undefined
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

function buildNotificationContent(
  type: string, 
  actor: Profile
): { title: string; body: string } {
  const name = actor.display_name || actor.username;
  
  switch (type) {
    case "like":
      return {
        title: "New Like",
        body: `${name} liked your post`,
      };
    case "follow":
      return {
        title: "New Follower",
        body: `${name} started following you`,
      };
    case "comment":
      return {
        title: "New Comment",
        body: `${name} commented on your post`,
      };
    default:
      return {
        title: "ThisDay",
        body: "You have a new notification",
      };
  }
}

async function generateAPNsJWT(): Promise<string> {
  const header = {
    alg: "ES256",
    kid: APNS_KEY_ID,
  };

  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: APNS_TEAM_ID,
    iat: now,
  };

  const encoder = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const claimsB64 = btoa(JSON.stringify(claims)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsignedToken = `${headerB64}.${claimsB64}`;

  // Import the private key
  const privateKeyPem = APNS_PRIVATE_KEY.replace(/\\n/g, "\n");
  const pemContents = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(unsignedToken)
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${unsignedToken}.${signatureB64}`;
}

async function sendAPNsPush(
  host: string,
  deviceToken: string,
  jwt: string,
  payload: {
    title: string;
    body: string;
    type: string;
    post_id?: string;
    actor_id?: string;
  }
): Promise<void> {
  const apnsPayload = {
    aps: {
      alert: {
        title: payload.title,
        body: payload.body,
      },
      sound: "default",
      badge: 1,
    },
    type: payload.type,
    post_id: payload.post_id,
    actor_id: payload.actor_id,
  };

  const response = await fetch(
    `https://${host}/3/device/${deviceToken}`,
    {
      method: "POST",
      headers: {
        "Authorization": `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify(apnsPayload),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`APNs error: ${response.status} - ${errorText}`);
  }
}
