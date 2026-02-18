// Edge Function para gestionar administradores via service role
// Acciones:
// - create_user: crea usuario en Supabase Auth y upsert en tabla administradores
// - change_password: cambia contraseña en Auth (si existe) y tabla administradores

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

if (!supabaseUrl || !serviceRoleKey) {
  console.error("Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY");
}

serve(async (req) => {
  try {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  let body: any;
  try {
    body = await req.json();
  } catch (_) {
    return new Response("Invalid JSON", { status: 400 });
  }

  const action = body?.action;

  if (action === "create_user") {
    const { email, password, nombre, rol = "admin", activo = true } = body;
    if (!email || !password || !nombre) {
      return new Response("email, password y nombre son obligatorios", { status: 400 });
    }

    // Crear usuario en Auth
    const { data: created, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nombre, rol, activo },
    });
    if (authError) {
      return new Response(authError.message, { status: 400 });
    }

    const userId = created.user?.id;

    // Upsert en tabla administradores
    const { error: dbError } = await supabase.from("administradores").upsert({
      id: userId, // se asocia el mismo id de Auth para consistencia
      email,
      password,
      nombre,
      rol,
      activo,
    });
    if (dbError) {
      return new Response(dbError.message, { status: 400 });
    }

    return new Response(JSON.stringify({ ok: true, user_id: userId }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  if (action === "change_password") {
    const { user_id, email, new_password } = body;
    if (!new_password || (!user_id && !email)) {
      return new Response("new_password y user_id o email son obligatorios", { status: 400 });
    }

    // Resolver userId si no viene
    let targetId = user_id;
    if (!targetId && email) {
      const { data: adminRow, error } = await supabase
        .from("administradores")
        .select("id")
        .eq("email", email)
        .maybeSingle();
      if (error) return new Response(error.message, { status: 400 });
      targetId = adminRow?.id;
    }

    // Cambiar password en Auth (si existe)
    if (targetId) {
      const { error: authError } = await supabase.auth.admin.updateUserById(targetId, {
        password: new_password,
      });
      // Si falla porque no existe en Auth, seguimos con la tabla
      if (authError && !authError.message.includes("User not found")) {
        return new Response(authError.message, { status: 400 });
      }
    }

    // Actualizar tabla administradores
    if (targetId) {
      const { error: dbError } = await supabase
        .from("administradores")
        .update({ password: new_password })
        .eq("id", targetId);
      if (dbError) return new Response(dbError.message, { status: 400 });
    } else if (email) {
      const { error: dbError } = await supabase
        .from("administradores")
        .update({ password: new_password })
        .eq("email", email);
      if (dbError) return new Response(dbError.message, { status: 400 });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response("Unknown action", { status: 400 });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err), stack: (err as Error)?.stack }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
