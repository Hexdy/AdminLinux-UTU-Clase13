# Soluciones — Clase 13

> Miralas **después** de intentar. Todas las variables van entre comillas, todos los bucles
> usan glob (nunca `$(ls)`) y todas las funciones declaran `local`.

## 1. `for` sobre un glob

```bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob                 # si no hay .log, el bucle no corre (ver abajo)

for f in datos/*.log; do
    n=$(wc -l < "$f")             # wc -l < archivo  -> solo el número, sin el nombre
    printf '%-28s %5d líneas\n' "$(basename "$f")" "$n"
done
```

**¿Y si no hay ningún `.log`?** Sin `shopt -s nullglob`, Bash te pasa el **patrón literal**
`datos/*.log` como si fuera un archivo, y `wc` te tira "No such file or directory". Dos
blindajes válidos: `shopt -s nullglob` (el bucle simplemente no corre) o
`[[ -e "$f" ]] || continue` como primera línea adentro del bucle.

## 2. `while read` salteando comentarios

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCHIVO="datos/servicios.txt"

while IFS= read -r servicio; do
    [[ -z "$servicio" ]] && continue        # línea vacía
    [[ "$servicio" == \#* ]] && continue    # comentario
    estado=$(systemctl is-active "$servicio" 2>/dev/null || true)
    printf '%-14s %s\n' "$servicio" "${estado:-desconocido}"
done < "$ARCHIVO"
```

- `IFS=` evita que se recorten espacios de la línea; `-r` evita que `\` se interprete.
- `is-active` devuelve **1** si el servicio no está activo: con `set -e` eso mataría el
  script, por eso `|| true`.
- Ojo multi-distro: el servicio de cron se llama `cron`, `cronie` o `crond` según tu
  distro. El archivo de ejemplo usa `cron`; si estás en Arch/Fedora, cambialo.

## 3. El bug del subshell

**Por qué falla**: cada lado de un `|` corre en un **subshell** (proceso hijo). El `while`
del lado derecho incrementa **su copia** de `total` y, cuando el bucle termina, ese proceso
muere con la copia adentro. El shell padre nunca se entera y sigue con `total=0`.

```bash
#!/usr/bin/env bash
set -euo pipefail

total=0
while IFS= read -r linea; do            # sin pipe: el bucle corre en ESTE shell
    total=$((total + 1))
done < datos/app_demo.log
echo "total=$total"
```

Otras dos formas válidas:

```bash
# process substitution: útil cuando necesitás filtrar antes
while IFS= read -r linea; do total=$((total + 1)); done < <(grep '\[ERROR\]' datos/app_demo.log)

# lastpipe: solo bash, y solo si el script no es interactivo
shopt -s lastpipe
grep '\[ERROR\]' datos/app_demo.log | while IFS= read -r l; do total=$((total + 1)); done
```

## 4. Campos separados por `;`

```bash
#!/usr/bin/env bash
set -euo pipefail

printf '%-10s | %s\n' "HOST" "IP"
printf -- '-----------+----------------\n'

while IFS=';' read -r host ip ambiente; do
    [[ -z "$host" || "$host" == \#* ]] && continue
    [[ "$ambiente" == "prod" ]] || continue
    printf '%-10s | %s\n' "$host" "$ip"
done < datos/hosts.txt
```

`IFS=';'` vale **solo** para ese `read`: parte la línea en tres variables. Si hubiera más
campos que variables, el último se queda con todo el resto.

## 5. Arrays

```bash
#!/usr/bin/env bash
set -euo pipefail

mapfile -t servicios < datos/servicios.txt

echo "elementos: ${#servicios[@]}"
echo "primero:   ${servicios[0]}"
echo "último:    ${servicios[-1]}"

for s in "${servicios[@]}"; do
    [[ -z "$s" || "$s" == \#* ]] && continue
    echo "-> $s"
done
```

`${#arr[@]}` = cantidad. `${arr[-1]}` = el último (Bash 4.3+). `"${arr[@]}"` **con
comillas** para que cada elemento siga siendo una palabra.

## 6. Funciones

```bash
#!/usr/bin/env bash
set -euo pipefail

contar_nivel() {
    local archivo="$1" nivel="$2"
    grep -c "\[${nivel}\]" "$archivo" || true    # grep -c sale con 1 si no encuentra nada
}

ARCHIVO="datos/app_demo.log"
for nivel in ERROR WARN INFO; do
    n=$(contar_nivel "$ARCHIVO" "$nivel")        # el DATO se captura con $( )
    printf '%-6s %3d\n' "$nivel" "$n"
done
```

**Con `return "$n"` y 500 errores**: `$?` te daría **244**. `return` devuelve un **código
de estado** de un solo byte (0-255): 500 da la vuelta (`500 - 256 = 244`). `return` no
sirve para devolver datos, solo para decir "salió bien / salió mal".

**Sin `local`**: `archivo` y `nivel` quedarían como variables **globales** y pisarían
cualquier variable del script que se llame igual. Es una de las fuentes de bugs más
difíciles de encontrar.

## 7. `trap` + `mktemp`

```bash
#!/usr/bin/env bash
set -euo pipefail

TMP="$(mktemp)"                                   # nombre único, permisos 600
trap 'rm -f "$TMP"' EXIT                          # salida normal, exit 1 o muerte por set -e
trap 'echo "cancelado" >&2; exit 130' INT TERM    # Ctrl+C y kill (señales de la Clase 9)

for f in datos/*.log; do
    printf '%s %s\n' "$(grep -c '\[ERROR\]' "$f" || true)" "$(basename "$f")" >> "$TMP"
done

sort -rn "$TMP"
echo "(el temporal $TMP se borra solo al salir)"
```

Probá las tres salidas: dejalo terminar, cortalo con `Ctrl+C`, y metele un `exit 1` a la
mitad. En los tres casos `ls /tmp/tmp.*` no deja basura tuya. **Nunca** uses un nombre fijo
tipo `/tmp/reporte.tmp`: otro usuario puede adelantarse y crearlo (o crear un symlink a un
archivo tuyo).

## 8. `logger` + `cron` + seguridad

**a) La función `log()`:**

```bash
readonly TAG="clase13"

log() {
    local nivel="$1"; shift
    printf '[%s] %s\n' "$nivel" "$*" >&2          # a la pantalla (stderr)
    logger -t "$TAG" -p "user.${nivel}" "$*"      # y al journal del sistema
}

log info "arranco el reporte"
log err  "no pude leer el directorio"
```

```bash
journalctl -t clase13 -n 10 --no-pager
journalctl -t clase13 -p err --since today --no-pager
```

**b) La línea de crontab:**

```
15 7 * * 1-5 /usr/local/bin/mi_reporte.sh >> /var/log/mi_reporte.log 2>&1
```

Se lee: *minuto 15, hora 7, cualquier día del mes, cualquier mes, de lunes a viernes*.

**c) Los tres problemas de la línea de la IA:**

```
15 7 * * 1-5 mi_reporte.sh > /tmp/reporte-$(date +%F).txt
```

1. **`mi_reporte.sh` sin ruta absoluta** → cron tiene un `PATH` mínimo
   (`/usr/bin:/bin`): no lo va a encontrar. Va `/usr/local/bin/mi_reporte.sh`.
2. **El `%` sin escapar** → en crontab, el primer `%` corta el comando y lo que sigue se
   manda por stdin. Va `\%F`… o mejor, el `date` adentro del script.
3. **`>` no captura los errores y pisa el archivo** → va `>>` y `2>&1` (o directamente
   `logger`, que es lo que hace el script). Además `/tmp` no es lugar para un log que
   querés conservar: cualquiera escribe ahí y se limpia solo.

Corregida:

```
15 7 * * 1-5 /usr/local/bin/mi_reporte.sh >> /var/log/mi_reporte.log 2>&1
```

**d) Permisos y secretos:**

`chmod 700 /usr/local/bin/mi_reporte.sh` (o `750` si un grupo también lo corre) y dueño el
usuario que lo ejecuta. **`777` significa que cualquier usuario de la máquina puede
reescribirlo**: como cron lo ejecuta solo, cualquiera tendría ejecución de código con los
permisos de ese usuario. Es una puerta trasera de manual.

El token **nunca** va adentro del script ni en el crontab (`crontab -l` lo muestra). Va en
un archivo aparte:

```bash
sudo install -o tienda -g tienda -m 600 /dev/null /etc/mi_reporte.conf
# adentro:  API_TOKEN=...
# en el script:
[[ -r /etc/mi_reporte.conf ]] && source /etc/mi_reporte.conf
```

o como variable de entorno provista por el gestor de servicios. Y el archivo de config, al
`.gitignore`.
