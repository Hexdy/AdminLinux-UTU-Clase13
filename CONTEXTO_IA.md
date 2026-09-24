# CONTEXTO PARA IA — AdminLinux · UTU · Clase 13

> 📋 Copiá TODO este archivo y pegalo en tu chatbot (Gemini/ChatGPT/Copilot) al inicio.

## Quién soy y qué estoy haciendo

Soy estudiante de "Administración de Sistemas Linux" (UTU, 2026), en la **Clase 13: Shell
scripting II — bucles, funciones, logs propios y tareas automáticas**. Trabajo en una **VM
Ubuntu** (mis compañeros usan Arch o Fedora: las tres valen).

Ya vi: pipes y redirecciones (C2), `grep`/regex (C3), `sed` (C4), `awk` (C5),
`find` + permisos (C6), red (C7), procesos y señales (C9), `systemd` + `journalctl` (C10),
SSH (C11) y **Shell scripting I (C12)**: shebang, `set -euo pipefail`, variables y comillas,
`$(...)`, argumentos `$1`/`$#`/`$@`, `read`, códigos de salida, `if`/`[[ ]]`, `case`,
`printf`, stderr, `bash -x`, `shellcheck`.

**Reglas para vos, IA:**
- Explicame **cada línea** antes de que corra nada, sobre todo si hay `rm`, `sudo`,
  redirecciones `>` o una línea de `crontab`.
- Si me escribís un bucle que borra, primero **mostrámelo con `echo`** en lugar del `rm`.
- **No me des la bandera del reto ni los números R1/R2/R3**: guiame para que los saque yo.
- Quiero **aprender**, no copiar.

## Lo que estoy viendo hoy

### Bucle `for`

```bash
for s in ssh cron nginx; do echo "$s"; done          # lista literal
for f in /var/log/*.log; do echo "$f"; done          # GLOB  <- la forma correcta
for i in {1..10}; do echo "$i"; done                 # rango
for i in {0..100..10}; do echo "$i"; done            # rango con paso
for a in "$@"; do echo "$a"; done                    # argumentos del script
for ((i=0; i<10; i++)); do echo "$i"; done           # estilo C
```

🔴 **Antipatrón que nunca se usa**: `for f in $(ls *.log)`. Bash parte la salida por
espacios, así que un archivo llamado `app viejo.log` se convierte en dos "archivos"
inexistentes. El glob (`for f in *.log`) no tiene ese problema. Y la variable **siempre**
entre comillas: `"$f"`.

Si el glob no matchea nada, Bash devuelve el patrón literal (`*.log`). Se blinda con
`shopt -s nullglob` o comprobando `[[ -e "$f" ]]` adentro.

### Bucle `while` y leer un archivo línea por línea

```bash
while [[ $n -lt 5 ]]; do n=$((n + 1)); done          # mientras la condición sea verdadera

while IFS= read -r linea; do                          # EL modismo para leer archivos
    echo "-> $linea"
done < "$ARCHIVO"
```

- `IFS=` (vacío) → no recortar espacios ni tabs del principio y del final de la línea.
- `-r` → no interpretar `\` como escape (una ruta de Windows sobreviviría entera).
- `< "$ARCHIVO"` → **redirección**, no pipe (ver el bug del subshell más abajo).
- `until` es el espejo de `while`: repite **hasta que** la condición se cumpla.

### `break` / `continue`

`break` sale del bucle, `continue` salta a la próxima vuelta. En bucles anidados,
`break 2` sale de dos niveles.

### 🔴 El bug del subshell (el que enloquece a todo el mundo)

```bash
total=0
cat app.log | while read -r l; do total=$((total+1)); done
echo "$total"     # imprime 0 (!!)
```

Cada lado de un pipe corre en un **subshell** (proceso hijo). El hijo modifica **su** copia
de `total` y al terminar se muere con todo adentro. Soluciones:

```bash
while read -r l; do total=$((total+1)); done < app.log      # 1) redirección (la mejor)
while read -r l; do ...; done < <(grep ERROR app.log)        # 2) process substitution
shopt -s lastpipe                                            # 3) solo bash, no interactivo
```

### Arrays

```bash
servicios=(ssh cron nginx)
servicios+=(postgresql)
echo "${servicios[0]}"        # un elemento
echo "${servicios[@]}"        # TODOS (entre comillas: cada uno una palabra)
echo "${#servicios[@]}"       # cuántos hay
for s in "${servicios[@]}"; do echo "$s"; done
mapfile -t lineas < archivo.txt   # cargar un archivo entero en un array
```

(Los arrays asociativos existen: `declare -A edad; edad[juan]=30`. No los uso todavía.)

### Funciones

```bash
log() {                       # se define ANTES de usarla
    local nivel="$1"          # 'local' = la variable no sale de la función
    shift
    printf '[%s] %s\n' "$nivel" "$*" >&2
}

contar_errores() {
    local archivo="$1"
    grep -c '\[ERROR\]' "$archivo"     # devuelve DATOS por stdout
}

n=$(contar_errores "app.log")          # se capturan con $( )
```

🔴 **`return` vs `echo`** — es LA confusión del tema:

| | `return N` | `echo dato` + `$(...)` |
|---|---|---|
| Qué devuelve | un **código de estado** 0-255 | **datos** (texto, números) |
| Se lee con | `$?` o `if funcion; then` | `var=$(funcion)` |
| Límite | `return 500` te da `244` (da la vuelta) | sin límite |
| Se usa para | "¿salió bien?" (0 = sí) | "¿cuánto dio?" |

Sin `local`, una variable de la función **pisa** la global del mismo nombre. Un script
ordenado define funciones arriba y abajo tiene un `main "$@"`.

### `trap` — limpiar al salir

```bash
TMP="$(mktemp)"                       # nombre único e impredecible
trap 'rm -f "$TMP"' EXIT              # se ejecuta SIEMPRE al salir
trap 'echo "cancelado"; exit 130' INT TERM
```

`EXIT` cubre salida normal, `exit 1` y muerte por `set -e`. Engancha con las señales de la
Clase 9 (`INT` = Ctrl+C, `TERM` = `kill` educado).

### `logger` — que el script deje rastro

```bash
logger -t respaldo -p user.info  "respaldo iniciado"
logger -t respaldo -p user.err   "no pude montar /respaldos"
journalctl -t respaldo -n 20 --no-pager     # leerlo (Clase 10)
journalctl -t respaldo -p err --since today --no-pager
```

Prioridades: `emerg` `alert` `crit` `err` `warning` `notice` `info` `debug`.
Patrón que uso: una función `log()` que escribe a stdout **y** a `logger`, así lo veo en
vivo y queda en el journal. Un script automatizado que no loguea es **invisible cuando
falla**.

### `cron` — que corra solo

```
*  *  *  *  *   comando
|  |  |  |  |
|  |  |  |  +-- día de la semana  (0-7; 0 y 7 = domingo)
|  |  |  +----- mes               (1-12)
|  |  +-------- día del mes       (1-31)
|  +----------- hora              (0-23)
+-------------- minuto            (0-59)
```

| Línea | Se lee |
|---|---|
| `30 2 * * *` | todos los días a las 02:30 |
| `*/15 * * * *` | cada 15 minutos |
| `0 9 * * 1-5` | de lunes a viernes a las 09:00 |
| `0 3 1 * *` | el día 1 de cada mes a las 03:00 |
| `0 22 * * 0` | los domingos a las 22:00 |

⚠️ Si ponés **día del mes Y día de semana** a la vez, cron hace **OR** (no AND).

Comandos: `crontab -e` (editar), `crontab -l` (listar), `crontab -r` (**borra todo sin
preguntar** — usá `crontab -l > respaldo.txt` antes). Atajos: `@daily`, `@hourly`,
`@weekly`, `@monthly`, `@reboot`.

Crontab **de usuario** (`crontab -e`) vs crontab **de sistema** (`/etc/crontab` y
`/etc/cron.d/<archivo>`): los de sistema llevan un **campo extra con el usuario** entre el
horario y el comando.

🔴 **Las 4 trampas de cron** (donde falla todo el mundo):

1. **`PATH` mínimo** (`/usr/bin:/bin`) → usá **rutas absolutas** para binarios y archivos.
2. **No hay entorno interactivo** → no existen tus alias ni las variables de tu `.bashrc`;
   si el script las necesita, definilas adentro del script.
3. **El `%` hay que escaparlo** (`\%`): en crontab, `%` sin escapar corta el comando y lo
   que sigue se le manda por stdin. Rompe cualquier `date +%F`.
4. **La salida se pierde** si no la redirigís → `>> /var/log/mi.log 2>&1` o `logger`.

Depurar un cron que "no anda": `journalctl -u cron` (Debian/Ubuntu), `-u cronie` (Arch),
`-u crond` (Fedora), o `journalctl -t CRON`. Y probar el comando con entorno vacío:
`env -i /bin/bash --noprofile --norc -c '/ruta/absoluta/script.sh'`.

### `systemd timers` vs `cron`

| | `cron` | `systemd timer` |
|---|---|---|
| Config | 1 línea | 2 units (`.timer` + `.service`) |
| Logging | te lo armás vos | **integrado** en el journal |
| Si la máquina estaba apagada | se perdió | `Persistent=true` lo corre al prender |
| Dependencias (`After=`) | no | sí |
| Hardening (`User=`, `ProtectSystem=`) | no | sí |
| Ver el próximo disparo | no | `systemctl list-timers` |

Regla práctica: tarea simple y personal → **cron**. Servicio de producción, con
dependencias, logging y hardening → **timer** (Clase 10).

## Seguridad de hoy (security by design)

- Permisos del script: `chmod 700` (o `750` con grupo). **Nunca `777`.**
- **Cero secretos hardcodeados**: van en un archivo aparte `chmod 600` que el script lee
  (`source /etc/miapp.conf`) o en una variable de entorno.
- Temporales con `mktemp` + `trap ... EXIT`, nunca `/tmp/archivo_fijo.tmp`.
- **Validar antes del bucle**: `[[ -d "$DIR" ]]` y `[[ -n "$DIR" ]]` antes de iterar.
- `rm` dentro de un `for`: probá **primero con `echo`** y mirá qué se expande.
- Cron con **usuario dedicado**, no root, si la tarea no necesita root.
- Comillas **siempre** alrededor de las variables.

## El reto de la bandera (Ansible + bucles)

En `playbooks/` hay un reto. Con `ansible-playbook armar_reto.yml -l local` se despliega el
material del incidente en `datos/reto/logs/`. Después **escribo un script con bucles y
funciones** que saque tres cosas de **todos** los `*.log` de esa carpeta:

- **R1**: total de líneas con el nivel `[ERROR]` exacto, sumando todos los archivos.
- **R2**: el archivo que acumuló más `[ERROR]`, **sin** la extensión `.log`.
- **R3**: dentro de ESE archivo, cuántas veces aparece el `code=EXXX` más repetido.

Armo `BANDERA{<R1>-<R2>-<R3>}` y verifico con
`ansible-playbook comprobar_bandera.yml -e "bandera=BANDERA{...}"`.

Hay **trampas a propósito**: un archivo con **espacio** en el nombre, un subdirectorio
`viejos/` con material del año pasado (que **no** cuenta), un `notas.txt` que no es `.log`,
líneas `[error]` en minúscula y líneas `[INFO]` que nombran la palabra ERROR. También hay
una **bandera señuelo** adentro del material viejo: no sirve.

Si te pido ayuda: **explicame el bucle**, hacéme verificar con `head`/`less` sobre un
archivo suelto antes de confiar en el total, y **no me des los números**.

## Preguntas típicas que te voy a hacer

- "¿Por qué mi variable vale 0 después del `while`?" (respuesta: el pipe, subshell)
- "¿Por qué `return 500` me da 244?"
- "Explicame `while IFS= read -r linea` palabra por palabra."
- "Revisá este crontab: ¿va a correr cuando yo creo?"
- "Mi script anda a mano pero no por cron, ¿qué miro primero?"
- "¿Cómo hago para que este script deje rastro si falla a las 3 AM?"

Recordá: explicame cada línea, mostrame el `rm` con `echo` primero, y no me des la bandera.
