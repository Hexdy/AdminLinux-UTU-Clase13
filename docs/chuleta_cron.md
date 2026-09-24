# Chuleta — `cron` (que el script corra solo)

## 1. Los 5 campos

```
   *      *      *      *      *      comando a ejecutar
   -      -      -      -      -
   |      |      |      |      |
   |      |      |      |      +----  dia de la SEMANA   0-7   (0 y 7 = domingo)
   |      |      |      +---------- mes                1-12  (o jan,feb,...)
   |      |      +----------------- dia del MES         1-31
   |      +------------------------ hora                0-23
   +------------------------------- minuto              0-59
```

Los cinco campos se leen de **izquierda a derecha, del más chico al más grande**.

| Símbolo | Qué significa | Ejemplo |
|---|---|---|
| `*` | cualquier valor | `* * * * *` = cada minuto |
| `,` | lista | `0,30 * * * *` = en el minuto 0 y en el 30 |
| `-` | rango | `0 9-18 * * *` = todas las horas de 9 a 18 |
| `*/n` | cada n | `*/15 * * * *` = cada 15 minutos |
| `0-30/10` | cada n dentro de un rango | en los minutos 0, 10, 20 y 30 |

## 2. Tabla de ejemplos leídos en castellano

| Línea | Se lee |
|---|---|
| `30 2 * * *` | todos los días a las **02:30** |
| `*/5 * * * *` | **cada 5 minutos** |
| `0 * * * *` | **en punto**, todas las horas |
| `0 9 * * 1-5` | de **lunes a viernes** a las 09:00 |
| `0 9 * * 6,0` | **sábados y domingos** a las 09:00 |
| `0 3 1 * *` | el **día 1** de cada mes a las 03:00 |
| `15 4 * * 0` | los **domingos** a las 04:15 |
| `0 0 1 1 *` | el **1 de enero** a medianoche |
| `*/10 8-20 * * 1-5` | cada 10 min, de 8 a 20, días hábiles |

⚠️ **La trampa del OR**: si completás **día del mes** *y* **día de semana** (los dos
distintos de `*`), cron ejecuta cuando se cumple **cualquiera de los dos**, no los dos.
`0 0 13 * 5` = el día 13 **o** cada viernes.

## 3. Atajos

| Atajo | Equivale a |
|---|---|
| `@yearly` / `@annually` | `0 0 1 1 *` |
| `@monthly` | `0 0 1 * *` |
| `@weekly` | `0 0 * * 0` |
| `@daily` / `@midnight` | `0 0 * * *` |
| `@hourly` | `0 * * * *` |
| `@reboot` | una vez, al arrancar la máquina |

## 4. Comandos

```bash
crontab -e        # editar TU crontab (lo valida al guardar)
crontab -l        # listar TU crontab
crontab -l > ~/crontab_respaldo.txt    # respaldo ANTES de tocar nada
crontab -r        # ⚠️ BORRA TODO tu crontab. Sin preguntar. Sin deshacer.
sudo crontab -l -u <usuario>           # ver el crontab de otro usuario
```

> 🔴 `crontab -r` está **pegadito** a `crontab -e` en el teclado. Hacé el respaldo. Siempre.

## 5. Crontab de usuario vs crontab de sistema

| | `crontab -e` (usuario) | `/etc/crontab` y `/etc/cron.d/<archivo>` |
|---|---|---|
| Dónde vive | `/var/spool/cron/...` (no se edita a mano) | archivos de texto normales |
| Quién lo corre | **vos** | el **usuario que digas** |
| Campos | 5 + comando | 5 + **usuario** + comando |
| Se versiona en git | incómodo | **sí** (por eso se usa en servidores) |

```
# /etc/cron.d/mantenimiento     <-- ojo: hay un campo MÁS (el usuario)
30 2 * * *  tienda  /usr/local/bin/mantenimiento_logs.sh /var/log/tienda
```

También existen los directorios `/etc/cron.daily/`, `/etc/cron.hourly/`, etc.: dejás un
script ejecutable adentro y se corre solo (sin línea de horario).

## 6. 🔴 Las 4 trampas de cron

### (a) El `PATH` es mínimo

Cron arranca con algo como `PATH=/usr/bin:/bin`. Tus `~/bin`, `/usr/local/bin`, el `PATH`
del `.bashrc`... **no existen**.

```
# ❌ "no anda por cron pero a mano sí"
0 3 * * * mantenimiento_logs.sh

# ✅ rutas absolutas para el binario Y para los archivos
0 3 * * * /usr/local/bin/mantenimiento_logs.sh /var/log/tienda
```

También podés declarar el `PATH` arriba del crontab:

```
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

### (b) No hay entorno interactivo

Cron **no** lee tu `.bashrc` ni tu `.profile`: no hay alias, ni `$EDITOR`, ni las
variables que exportás en tu sesión, ni `cd` a tu `$HOME` como vos lo dejás. Si tu script
necesita algo, lo define **adentro del script**.

### (c) El `%` hay que escaparlo

En un crontab, `%` **no** es un carácter común: el primero corta el comando y todo lo que
sigue se le manda al comando por **stdin** (así se le pasa texto a `mail`).

```
# ❌ se ejecuta "/usr/bin/tar czf /respaldos/app-" y el resto va a stdin
0 1 * * * /usr/bin/tar czf /respaldos/app-$(date +%F).tgz /srv/app

# ✅ escapado
0 1 * * * /usr/bin/tar czf /respaldos/app-$(date +\%F).tgz /srv/app
```

> Truco de la vida real: metelo todo adentro de un script `.sh` y que el crontab llame al
> script. Ahí adentro el `%` no tiene nada de especial.

### (d) La salida se pierde

Si tu comando imprime algo, cron intenta **mandártelo por mail local**. Si no hay MTA
configurado (el caso normal hoy), esa salida **se pierde**. Un error a las 3 AM que nadie
ve es un error que no existe... hasta que te explota.

```
# ✅ opción 1: archivo de log propio (>> agrega, > pisa)
30 2 * * * /usr/local/bin/mantenimiento_logs.sh >> /var/log/mantenimiento.log 2>&1

# ✅ opción 2 (mejor): que el script use logger y lo leés con journalctl
30 2 * * * /usr/local/bin/mantenimiento_logs.sh

# ⚠️ lo que NO hay que hacer: tirar todo a la basura
30 2 * * * /usr/local/bin/mantenimiento_logs.sh >/dev/null 2>&1
```

## 7. Depurar un cron que "no anda"

```bash
# 1) ¿El demonio está vivo?  (el nombre CAMBIA según la distro)
systemctl status cron        # Debian/Ubuntu
systemctl status cronie      # Arch
systemctl status crond       # Fedora/RHEL
systemctl list-units '*cron*'   # ante la duda

# 2) ¿Cron intentó ejecutar tu tarea?
journalctl -u cron --since today --no-pager      # cambiá cron por cronie/crond
journalctl -t CRON --since today --no-pager

# 3) ¿Tu script dejó rastro?  (si usa logger)
journalctl -t mantenimiento --since today --no-pager

# 4) Reproducí el entorno pobre de cron:
env -i /bin/bash --noprofile --norc -c '/usr/local/bin/mantenimiento_logs.sh'

# 5) Mientras probás, bajá el horario a */2 y miralo en vivo:
journalctl -t mantenimiento -f
```

Checklist rápido: ¿ruta absoluta? · ¿el script es **ejecutable** (`chmod 700`)? · ¿tiene
**shebang**? · ¿está en **LF** y no en CRLF? · ¿redirigís la salida? · ¿escapaste el `%`? ·
¿el usuario del crontab tiene permiso sobre los archivos?

## 8. `cron` vs `systemd timer`

| | `cron` | `systemd timer` |
|---|---|---|
| Config | 1 línea | 2 units (`.timer` + `.service`) |
| Logging | te lo armás vos | **integrado** en el journal |
| Máquina apagada a esa hora | se perdió | `Persistent=true` lo corre al prender |
| Dependencias (`After=`, `Requires=`) | no | sí |
| Hardening (`User=`, `ProtectSystem=`) | no | sí |
| Ver próximo disparo | no | `systemctl list-timers` |
| Curva de aprendizaje | 5 minutos | un rato |

**Regla práctica**: tarea personal, simple, de una línea → **cron**. Tarea de producción,
con dependencias, logging y permisos acotados → **timer** (Clase 10).

## 9. Multi-distro

| | Debian / Ubuntu | Arch | Fedora / RHEL |
|---|---|---|---|
| Paquete | `cron` | `cronie` | `cronie` |
| Unit | `cron.service` | `cronie.service` | `crond.service` |
| Instalar | `sudo apt install cron` | `sudo pacman -S cronie` | `sudo dnf install cronie` |
| Habilitar | `sudo systemctl enable --now cron` | `... --now cronie` | `... --now crond` |

En Arch y en varias imágenes mínimas de Fedora, **cron no viene instalado** (systemd usa
timers). La **sintaxis del crontab es idéntica** en las tres.

## 10. Seguridad

- El script del crontab, `chmod 700` (o `750` con grupo) y dueño el usuario que lo corre.
  Si cualquiera puede **escribirlo**, cualquiera ejecuta código como ese usuario.
- **Cero secretos** en el crontab: `crontab -l` lo muestra y queda en el spool.
  Van en un archivo `0600` que el script lee.
- Usá un **usuario dedicado** (`/etc/cron.d/` te deja elegirlo) en vez de root.
- `/etc/cron.allow` y `/etc/cron.deny` controlan **quién** puede tener crontab.
- Antes de instalar una tarea que borra, **probala con `echo`** en lugar del `rm` y mirá la
  salida un par de días.

## 11. 🤖 IA con criterio

Pedile una línea de cron a un LLM y **verificá 4 cosas** antes de instalarla:

1. ¿Usa **rutas absolutas** (binario y archivos)?
2. ¿**Redirige la salida** a un log o usa `logger`?
3. ¿El **día de semana** es el que creés? (las IAs se equivocan feo acá: `0` es domingo,
   no lunes, y `1-5` es lunes a viernes).
4. ¿Escapó el `%` si hay un `date +%F`?

Y leé el horario **en voz alta en castellano** antes de guardar. Si no lo podés explicar,
no lo instales.
