# limpiador-windows

Script `.bat` para liberar espacio en Windows 10/11. Tipo CCleaner casero, sin instalar nada.

## Uso

1. Descargar `limpiar_espacio.bat` (o `git clone`).
2. Doble clic. Pide permisos de administrador solo.
3. Esperar 10-20 min. Al final muestra cuántos GB liberó.
4. Reiniciar la PC.

## Qué limpia

| Paso | Qué | Notas |
|---|---|---|
| 1 | Cierra navegadores y WhatsApp | Primero cierre normal, después forzado |
| 2 | Residuos de updates (`$WINDOWS.~BT`, `$WinREAgent`, `SoftwareDistribution\Download`, caché Delivery Optimization) | |
| 3 | WinSxS con DISM | Con `/ResetBase` no se pueden desinstalar updates viejos |
| 4 | Hibernación (`hiberfil.sys`) | `auto`: solo en PCs de escritorio, notebooks no se tocan |
| 5 | `%TEMP%` y `Windows\Temp` | Archivos en uso se saltean |
| 6 | Caché de Chrome, Edge, Brave (todos los perfiles) y Firefox | No borra historial, contraseñas ni cookies |
| 7 | Caché de WhatsApp | No borra chats ni cierra sesión |
| 8 | Papelera y miniaturas | |
| 9 | Liberador de espacio de Windows (`cleanmgr`) | Todas las categorías **menos Descargas** |

## Configuración por PC

Arriba del `.bat`:

```bat
set "CERRAR_NAVEGADORES=1"
set "LIMPIAR_WHATSAPP=1"
set "DESACTIVAR_HIBERNACION=auto"   :: auto | 1 | 0
set "RESETBASE=1"
set "USAR_CLEANMGR=1"
```

## Sacar apps del inicio: `desactivar_inicio.bat`

Doble clic. Saca del arranque de Windows las apps que comen RAM en segundo plano (siguen instaladas):
Codex / ChatGPT, CCleaner (y su servicio pasa a Manual), Edge en segundo plano, Teams, Firefox, WhatsApp.

- Muestra todo lo que arranca con Windows: `APAGADO` (lo cambió), `ya off`, `sigue` (no está en la lista).
- Para agregar o sacar apps: editar la lista `$Apagar` arriba de `desactivar_inicio.ps1`.
- Probar sin cambiar nada: `powershell -ExecutionPolicy Bypass -File desactivar_inicio.ps1 -Simular`
- Reactivar una app: Administrador de tareas → Aplicaciones de arranque → Habilitar.

## Salvedades

- Usuario sin permisos de admin: si otra cuenta pone la contraseña de admin, los temporales/cachés que limpia son los de **esa** cuenta, no los del usuario actual.
- Desactivar hibernación también desactiva el Inicio rápido. Para volver: `powercfg -h on`.
- Si Windows bloquea el `.bat` descargado (SmartScreen): clic derecho → Propiedades → **Desbloquear**.
- `$WINDOWS.~BT` a veces no se deja borrar a mano; en ese caso lo limpia `cleanmgr` en el paso 9.
