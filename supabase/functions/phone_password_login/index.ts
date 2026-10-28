import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

function normalizePhone(input: unknown): string {
  const arabicDigits = "";
  let value = String(input ?? "").trim();

  for (let i = 0; i < arabicDigits.length; i++) {
    value = value.replaceAll(arabicDigits[i], String(i));
  }

  value = value.replace(/[\s().-]/g, "");

  if (value.startsWith("00")) {
    value = "+" + value.slice(2);
  }

  if (!value.startsWith("+")) {
    if (value.startsWith("20")) {
      value = "+" + value;
    } else if (value.startsWith("0")) {
      value = "+20" + value.slice(1);
    } else {
      value = "+" + value;
    }
  }

  return value;
}

function genericAuthError() {
  return json(
    {
      error: "INVALID_CREDENTIALS",
      message: "رقم الهاتف أو كلمة المرور غير صحيحة.",
    },
    401,
  );
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
    const body = await req.json();

    const phone = normalizePhone(body?.phone);

    const password =
      typeof body?.password === "string"
        ? body.password
        : "";

    if (
      !/^\+[1-9]\d{7,14}$/.test(phone) ||
      password.length < 1 ||
      password.length > 256
    ) {
      return genericAuthError();
    }

    const supabaseUrl =
      Deno.env.get("SUPABASE_URL");

    const secretKeysRaw =
      Deno.env.get("SUPABASE_SECRET_KEYS");

    const publishableKeysRaw =
      Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");

    if (
      !supabaseUrl ||
      !secretKeysRaw ||
      !publishableKeysRaw
    ) {
      console.error(
        "Missing required Supabase runtime keys.",
      );

      return json(
        {
          error: "SERVER_CONFIGURATION_ERROR",
        },
        500,
      );
    }

    const secretKeys =
      JSON.parse(secretKeysRaw);

    const publishableKeys =
      JSON.parse(publishableKeysRaw);

    const secretKey =
      secretKeys["default"];

    const publishableKey =
      publishableKeys["default"];

    if (!secretKey || !publishableKey) {
      console.error(
        "Default Supabase API keys are unavailable.",
      );

      return json(
        {
          error: "SERVER_CONFIGURATION_ERROR",
        },
        500,
      );
    }

    // The phone is resolved by public.profile_auth_identity_by_phone, which
    // compares both sides through public.hena_normalize_phone. A raw
    // PostgREST filter (phone=eq.<value>) only matches the exact stored
    // format, so it used to miss accounts stored as "01001234567".
    const profileUrl =
      supabaseUrl +
      "/rest/v1/rpc/profile_auth_identity_by_phone" +
      "?select=id,email,is_active";

    const profileResponse =
      await fetch(profileUrl, {
        method: "POST",
        headers: {
          apikey: secretKey,
          Authorization:
            "Bearer " + secretKey,
          "Content-Type":
            "application/json",
          Accept:
            "application/json",
        },
        body: JSON.stringify({
          p_phone: phone,
        }),
      });

    if (!profileResponse.ok) {
      const details =
        await profileResponse.text();

      console.error(
        "Profile lookup failed:",
        profileResponse.status,
        details,
      );

      return json(
        {
          error: "SERVER_ERROR",
        },
        500,
      );
    }

    const profiles =
      await profileResponse.json();

    const profile =
      Array.isArray(profiles)
        ? profiles[0]
        : null;

    if (
      !profile ||
      profile.is_active !== true
    ) {
      return genericAuthError();
    }

    // The email is the authentication identity of every account: the phone
    // provider is disabled in the project, so the auth server rejects a
    // password grant made with a phone. The phone stays the identifier the
    // customer types, and it is resolved to its email here.
    const email =
      typeof profile.email === "string"
        ? profile.email.trim()
        : "";

    if (!email) {
      console.error(
        "The account has no email identity and cannot sign in.",
      );

      return genericAuthError();
    }

    const tokenResponse =
      await fetch(
        supabaseUrl +
          "/auth/v1/token?grant_type=password",
        {
          method: "POST",
          headers: {
            "Content-Type":
              "application/json",
            apikey: publishableKey,
          },
          body: JSON.stringify({
            email: email,
            password,
          }),
        },
      );

    if (!tokenResponse.ok) {
      if (
        tokenResponse.status === 400 ||
        tokenResponse.status === 401
      ) {
        return genericAuthError();
      }

      const details =
        await tokenResponse.text();

      console.error(
        "Auth token endpoint failed:",
        tokenResponse.status,
        details,
      );

      return json(
        {
          error: "AUTH_SERVER_ERROR",
        },
        502,
      );
    }

    const token =
      await tokenResponse.json();

    if (
      !token?.access_token ||
      !token?.refresh_token
    ) {
      console.error(
        "Auth token response was incomplete.",
      );

      return json(
        {
          error: "AUTH_SERVER_ERROR",
        },
        502,
      );
    }

    return json({
      access_token:
        token.access_token,
      refresh_token:
        token.refresh_token,
      expires_in:
        token.expires_in,
      expires_at:
        token.expires_at,
      token_type:
        token.token_type,
    });
  } catch (error) {
    console.error(
      "Unhandled phone password login error:",
      error,
    );

    return json(
      {
        error: "INVALID_REQUEST",
      },
      400,
    );
  }
});