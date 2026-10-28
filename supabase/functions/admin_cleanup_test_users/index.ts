import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// TEMPORARY maintenance function.
//
// It removes the accounts that were created while testing the phone sign-in
// fix. It is deliberately restricted: the email prefix is hard coded, so the
// function can never touch a real customer account, and it is deleted right
// after the cleanup.
//
// The legacy service_role keys are disabled on this project, so the only way
// to reach the admin API is through the keys the platform injects into the
// function runtime (SUPABASE_SECRET_KEYS).

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TEST_EMAIL_PREFIX = "hena.selftest.";

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return json(
      {
        error: "METHOD_NOT_ALLOWED",
      },
      405,
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const secretKeysRaw = Deno.env.get("SUPABASE_SECRET_KEYS");

    if (!supabaseUrl || !secretKeysRaw) {
      console.error("Missing Supabase runtime keys.");

      return json(
        {
          error: "SERVER_CONFIGURATION_ERROR",
        },
        500,
      );
    }

    const secretKeys = JSON.parse(secretKeysRaw);
    const secretKey = secretKeys["default"];

    if (!secretKey) {
      console.error("Default Supabase secret key is unavailable.");

      return json(
        {
          error: "SERVER_CONFIGURATION_ERROR",
        },
        500,
      );
    }

    const headers = {
      apikey: secretKey,
      Authorization: "Bearer " + secretKey,
      "Content-Type": "application/json",
    };

    // 1. List the auth users whose email carries the test prefix.
    const listResponse = await fetch(
      supabaseUrl +
        "/auth/v1/admin/users?page=1&per_page=200",
      {
        method: "GET",
        headers,
      },
    );

    if (!listResponse.ok) {
      const details = await listResponse.text();

      console.error(
        "Admin list failed:",
        listResponse.status,
        details,
      );

      return json(
        {
          error: "SERVER_ERROR",
        },
        500,
      );
    }

    const list = await listResponse.json();
    const users = Array.isArray(list?.users) ? list.users : [];

    const targets = users.filter((user: { email?: string }) =>
      typeof user?.email === "string" &&
      user.email.startsWith(TEST_EMAIL_PREFIX)
    );

    const deleted: string[] = [];
    const failed: { id: string; status: number }[] = [];

    for (const user of targets) {
      const deleteResponse = await fetch(
        supabaseUrl + "/auth/v1/admin/users/" + user.id,
        {
          method: "DELETE",
          headers,
        },
      );

      if (deleteResponse.ok) {
        deleted.push(user.id);
      } else {
        failed.push({
          id: user.id,
          status: deleteResponse.status,
        });
      }
    }

    // 2. Remove any profile row that outlived its auth user.
    const profileResponse = await fetch(
      supabaseUrl + "/rest/v1/profiles?email=like." +
        encodeURIComponent(TEST_EMAIL_PREFIX + "*"),
      {
        method: "DELETE",
        headers: {
          ...headers,
          Prefer: "return=representation",
        },
      },
    );

    const profileRows = profileResponse.ok
      ? await profileResponse.json()
      : [];

    console.log(
      "Cleanup done. deleted=",
      deleted.length,
      "failed=",
      failed.length,
      "profiles=",
      Array.isArray(profileRows) ? profileRows.length : 0,
    );

    return json({
      deleted,
      failed,
      profiles_removed: Array.isArray(profileRows)
        ? profileRows.length
        : 0,
    });
  } catch (error) {
    console.error("Cleanup error:", error);

    return json(
      {
        error: "INVALID_REQUEST",
      },
      400,
    );
  }
});
