import { createClient } from "npm:@supabase/supabase-js@2";

const REVENUECAT_API_URL =
  "https://api.revenuecat.com/v1/subscribers";
const ENTITLEMENT_ID = "aika_stream_premium";

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed." });
  }

  try {
    const payload = await req.json();
    const code = typeof payload.code === "string" ? payload.code : "";
    const appUserId =
      typeof payload.app_user_id === "string" ? payload.app_user_id : "";

    if (!code.trim() || !appUserId.trim()) {
      return json(400, { error: "Parameters missing." });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const rcSecret = Deno.env.get("REV_CAT_SECRET") ?? "";
    if (!supabaseUrl || !serviceRole || !rcSecret) {
      return json(500, { error: "Server is not configured." });
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRole);
    const sanitizedCode = code.trim().toUpperCase();
    const codeHash = await sha256Hex(sanitizedCode);

    const { data: coupon, error: claimError } = await supabaseAdmin.rpc(
      "claim_coupon",
      {
        p_code_hash: codeHash,
        p_app_user_id: appUserId.trim(),
      },
    );

    const claimed = Array.isArray(coupon) ? coupon[0] : coupon;
    if (claimError || !claimed?.id) {
      return json(403, {
        error: "Invalid, expired, or already claimed pass.",
      });
    }

    const rcResponse = await fetch(
      `${REVENUECAT_API_URL}/${encodeURIComponent(appUserId.trim())}/entitlements/${ENTITLEMENT_ID}/promotional`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${rcSecret}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ duration: claimed.duration }),
      },
    );

    if (!rcResponse.ok) {
      await supabaseAdmin.rpc("unclaim_coupon", { p_coupon_id: claimed.id });
      return json(502, {
        error: "Store sync execution failed. Token restored.",
      });
    }

    return json(200, { success: true, duration: claimed.duration });
  } catch {
    return json(500, { error: "Redeem failed." });
  }
});
