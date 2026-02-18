# Edge Function: manage-admin

Función para crear usuarios admin y cambiar contraseñas usando la `service_role` y mantener sincronizado Supabase Auth con la tabla `administradores`.

## Acciones soportadas
- `create_user`: crea usuario en Auth y upsert en `administradores`.
  - Campos: `email` (req), `password` (req), `nombre` (req), `rol` (default `admin`), `activo` (default `true`).
- `change_password`: cambia contraseña en Auth (si existe) y en `administradores`.
  - Campos: `new_password` (req) y `user_id` o `email` (uno obligatorio).

## Deploy
1. Copiar `supabase/functions/manage-admin/index.ts`.
2. Definir las env vars en el proyecto Supabase:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Deploy:
```bash
supabase functions deploy manage-admin --project-ref <tu-project-ref>
```

## Uso desde Flutter
El servicio ya intenta llamar a la función antes del fallback a la tabla:
- Alta de usuario: `createAdmin(...)` invoca `manage-admin` con `action: create_user`.
- Cambio de contraseña: `changeAdminPassword(...)` invoca `manage-admin` con `action: change_password`.

Si la función no está desplegada o falla, el código cae al comportamiento anterior (solo tabla `administradores`).
