import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const authevoKey = Deno.env.get("AUTHEVO_KEY");
const hookSecret = Deno.env.get("SEND_SMS_HOOK_SECRET")?.replace(
  "v1,whsec_",
  "",
);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  if (!authevoKey) {
    console.error("AUTHEVO_KEY is missing");
    return new Response(
      JSON.stringify({
        error: {
          http_code: 500,
          message: "AUTHEVO_KEY is not configured",
        },
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  if (!hookSecret) {
    console.error("SEND_SMS_HOOK_SECRET is missing");
    return new Response(
      JSON.stringify({
        error: {
          http_code: 500,
          message: "SEND_SMS_HOOK_SECRET is not configured",
        },
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  try {
    const payload = await req.text();
    const headers = Object.fromEntries(req.headers);

    const webhook = new Webhook(hookSecret);
    const { user, sms } = webhook.verify(payload, headers);

    const phone = user?.phone;
    const otp = sms?.otp;

    if (!phone || !otp) {
      return new Response(
        JSON.stringify({
          error: {
            http_code: 400,
            message: "Missing user.phone or sms.otp",
          },
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const response = await fetch(
      "https://api.authevo.dev/v1/otp/deliver",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${authevoKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          phone,
          code: otp,
        }),
      },
    );

    const responseText = await response.text();

    if (!response.ok) {
      console.error("Authevo delivery failed:", response.status, responseText);

      return new Response(
        JSON.stringify({
          error: {
            http_code: 502,
            message: "WhatsApp OTP delivery failed",
          },
        }),
        {
          status: 502,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    console.log("WhatsApp OTP delivered:", responseText);

    return new Response("{}", {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send_whatsapp_otp error:", error);

    return new Response(
      JSON.stringify({
        error: {
          http_code: 500,
          message: "Failed to process Send SMS Hook",
        },
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
