import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-api-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const configuredApiKey = Deno.env.get("NAVISLI_API_KEY");
  const suppliedApiKey = request.headers.get("x-api-key");

  if (!configuredApiKey || !suppliedApiKey || suppliedApiKey !== configuredApiKey) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing required Supabase environment variables");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Request body must be valid JSON" }, 400);
  }

  const query = typeof payload.query === "string" ? payload.query.trim() : null;
  const category = typeof payload.category === "string" ? payload.category.trim() : null;
  const area = typeof payload.area === "string" ? payload.area.trim() : null;
  const requestedLimit = typeof payload.limit === "number" ? Math.trunc(payload.limit) : 10;
  const limit = Math.min(Math.max(requestedLimit, 1), 50);

  if (query && query.length > 200) {
    return jsonResponse({ error: "query must be 200 characters or fewer" }, 400);
  }
  if (category && category.length > 100) {
    return jsonResponse({ error: "category must be 100 characters or fewer" }, 400);
  }
  if (area && area.length > 100) {
    return jsonResponse({ error: "area must be 100 characters or fewer" }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase.rpc("search_places", {
    p_query: query || null,
    p_category: category || null,
    p_area: area || null,
    p_limit: limit,
  });

  if (error) {
    console.error("search_places RPC failed", error);
    return jsonResponse({ error: "Search failed" }, 500);
  }

  return jsonResponse({
    count: data?.length ?? 0,
    results: data ?? [],
  });
});
