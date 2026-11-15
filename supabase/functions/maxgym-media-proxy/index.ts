// Supabase Edge Function: maxgym-media-proxy
// Serves 873 global exercises JSON & exercise images through Supabase Edge (No VPN / No CORS issues)

const UPSTREAM_CDN = "https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const mode = url.searchParams.get("mode") ?? "image";
    const path = url.searchParams.get("path") ?? "";

    // ۱. حالت دریافت کل بانک ۸۷۳ حرکت جهانی
    if (mode === "catalog") {
      const resp = await fetch(`${UPSTREAM_CDN}/dist/exercises.json`);
      if (!resp.ok) {
        return new Response(JSON.stringify({ error: "Upstream catalog unavailable" }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const data = await resp.text();
      return new Response(data, {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json; charset=utf-8",
          "Cache-Control": "public, max-age=86400",
        },
      });
    }

    // ۲. حالت پروکسی تصویر حرکت (جلوگیری از Path Traversal با اعتبارسنجی دقیق)
    const cleanPath = path.replace(/[^a-zA-Z0-9_\-\/\.]/g, "").replace(/\.\./g, "");
    if (!cleanPath || (!cleanPath.endsWith(".jpg") && !cleanPath.endsWith(".png"))) {
      return new Response("Invalid image path", { status: 400, headers: corsHeaders });
    }

    const imageUpstreamUrl = `${UPSTREAM_CDN}/exercises/${cleanPath}`;
    const imgResp = await fetch(imageUpstreamUrl);
    if (!imgResp.ok) {
      return new Response("Image not found", { status: 404, headers: corsHeaders });
    }

    const imageBytes = await imgResp.arrayBuffer();
    return new Response(imageBytes, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": cleanPath.endsWith(".png") ? "image/png" : "image/jpeg",
        "Cache-Control": "public, max-age=31536000, immutable",
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
