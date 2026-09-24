# Chuleta — bucles, arrays y funciones (Clase 13)

> De la **Clase 12** ya traés: `#!/usr/bin/env bash`, `set -euo pipefail`, comillas,
> `$(...)`, `$1`/`$#`/`$@`, `if`/`[[ ]]`, `case`, `printf`, `>&2`, `bash -x`, `shellcheck`.
> Esto es lo **nuevo**.

## 1. `for`

```bash
for s in ssh cron nginx; do echo "$s"; done        # lista literal
for f in /var/log/*.log; do echo "$f"; done        # GLOB  <- la forma correcta
for i in {1..10}; do echo "$i"; done               # rango
for i in {0..100..10}; do echo "$i"; done          # rango con paso
for a in "$@"; do echo "$a"; done                  # argumentos del script
for ((i = 0; i < 10; i++)); do echo "$i"; done     # estilo C (contador)
```

### 🔴 El antipatrón que NO se usa

```bash
for f in $(ls *.log); do ... done      # ❌ MAL
```

Bash parte la salida de `ls` por **espacios**. Si existe `app viejo.log`, el bucle ve
`app` y `viejo.log`: dos archivos que no existen. Además se comen los saltos de línea y se
vuelven a expandir los globs. **Nunca parsees `ls`.**

```bash
for f in *.log; do ... done            # ✅ BIEN (y "$f" entre comillas adentro)
```

### Cuando el glob no matchea nada

Si no hay ningún `.log`, Bash te pasa el **patrón literal** `*.log` como si fuera un
archivo. Dos blindajes:

```bash
shopt -s nullglob                      # el glob vacío no devuelve nada
# o bien, adentro del bucle:
[[ -e "$f" ]] || continue
```

### Recorrer archivos con nombres "hostiles" (espacios, saltos de línea)

```bash
find /var/log -name '*.log' -print0 | while IFS= read -r -d '' f; do
    echo "-> $f"
done
```

`-print0` / `-d ''` separan por byte nulo, el único carácter que un nombre de archivo no
puede contener.

## 2. `while`, `until` y leer un archivo línea por línea

```bash
n=0
while [[ $n -lt 5 ]]; do
    n=$((n + 1))
done

until ping -c1 -W1 10.20.30.11 >/dev/null 2>&1; do   # el espejo de while
    echo "esperando a web01..."
    sleep 2
done
```

### EL modismo que vas a copiar toda tu vida

```bash
while IFS= read -r linea; do
    printf '%s\n' "$linea"
done < "$ARCHIVO"
```

| Pieza | Por qué está |
|---|---|
| `IFS=` | vacía el separador **solo para este `read`**: no recorta espacios/tabs del principio ni del final de la línea. |
| `-r` | **raw**: no interpreta `\` como escape. Sin esto, `C:\temp\nuevo` pierde caracteres. |
| `< "$ARCHIVO"` | redirección: el bucle corre en **tu** shell, no en un subshell (ver punto 4). |

Leer campos separados por otra cosa:

```bash
while IFS=';' read -r host ip ambiente; do
    [[ "$host" == \#* || -z "$host" ]] && continue     # saltear comentarios y vacías
    echo "$host -> $ip ($ambiente)"
done < datos/hosts.txt
```

## 3. `break` y `continue`

```bash
for f in *.log; do
    [[ -s "$f" ]] || continue          # vacío -> próxima vuelta
    grep -q 'PANIC' "$f" && { echo "encontrado en $f"; break; }   # cortar acá
done
```

En bucles anidados, `break 2` sale de **dos** niveles (y `continue 2` salta a la próxima
vuelta del bucle de afuera).

## 4. 🔴 El bug del subshell (memorizalo)

```bash
total=0
cat app.log | while read -r l; do total=$((total + 1)); done
echo "$total"        # ❌ imprime 0
```

Cada lado de un `|` corre en un **proceso hijo**. El hijo se lleva una **copia** de
`total`, la modifica y se muere con ella adentro. El padre nunca se entera.

```
   padre (total=0)
        |
        |  crea 2 hijos para el pipe
        V
   [ cat ] ---> [ while  total=1,2,3... ]     <-- este total muere acá
        |
        V
   padre sigue con total=0
```

Soluciones, en orden de preferencia:

```bash
while read -r l; do total=$((total + 1)); done < app.log        # 1) redirección
while read -r l; do total=$((total + 1)); done < <(grep X app.log)   # 2) process substitution
shopt -s lastpipe        # 3) solo bash, y solo si el script NO es interactivo
```

Mismo problema con `total=$(...)` dentro de un `for` que corre en background, o con
`read` dentro de `find ... | while`.

## 5. Arrays

```bash
servicios=(ssh cron nginx)
servicios+=(postgresql)                 # agregar
echo "${servicios[0]}"                  # un elemento (empieza en 0)
echo "${servicios[@]}"                  # todos
echo "${#servicios[@]}"                 # cuántos hay
echo "${#servicios[2]}"                 # largo del elemento 2
unset 'servicios[1]'                    # borrar uno

for s in "${servicios[@]}"; do          # SIEMPRE con comillas
    echo "$s"
done

mapfile -t lineas < datos/servicios.txt # cargar un archivo entero (una línea por elemento)
echo "${#lineas[@]}"
```

`"${arr[@]}"` = cada elemento es una palabra (lo que querés).
`"${arr[*]}"` = todo junto en **una** palabra. Casi siempre querés `@`.

> Existen los **asociativos** (`declare -A edad; edad[juan]=30; echo "${edad[juan]}"`),
> muy útiles para contar. Es material de auto-estudio: con `sort | uniq -c` alcanza para
> esta clase.

## 6. Funciones

```bash
saludar() {                    # se define ANTES de llamarla
    local nombre="$1"          # 'local' = muere al terminar la función
    printf 'Hola, %s\n' "$nombre"
}

saludar "Ana"                  # se llama por el nombre, sin paréntesis
```

Adentro de la función, `$1`, `$2`, `$@` y `$#` son los **argumentos de la función**, no los
del script. `$0` sigue siendo el script.

### 🔴 `return` vs `echo` — LA confusión del tema

```bash
contar_mal() {
    local n
    n=$(grep -c ERROR "$1")
    return "$n"               # ❌ si n=500, $? te da 244
}

contar_bien() {
    grep -c '\[ERROR\]' "$1"  # ✅ escribe el DATO por stdout
}

n=$(contar_bien app.log)      # y lo capturás con $( )
```

| | `return N` | `echo`/`printf` + `$(...)` |
|---|---|---|
| Qué devuelve | **código de estado** 0-255 | **datos** |
| Se lee con | `$?` o `if funcion; then` | `var=$(funcion)` |
| `return 500` | da `244` (`500 mod 256`) | no aplica |
| Semántica | "¿salió bien?" (0 = sí) | "¿cuánto dio?" |

Si la función imprime datos, **los mensajes van a stderr** (`>&2`), o se te mezclan con el
resultado.

### Sin `local` pisás las globales

```bash
archivo="importante.txt"
procesar() { archivo="/tmp/basura"; }     # ❌ sin local
procesar
echo "$archivo"                            # /tmp/basura  (¡te pisó la global!)
```

### Estructura de un script ordenado

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1) constantes    2) funciones    3) main "$@"  al final
main() {
    validar "$@"
    procesar "$1"
}
main "$@"
```

## 7. `trap` — limpiar al salir

```bash
TMP="$(mktemp)"                      # nombre único, permisos 600, en el dir correcto
trap 'rm -f "$TMP"' EXIT             # se ejecuta SIEMPRE al salir
trap 'echo "cancelado por el usuario" >&2; exit 130' INT TERM
```

`EXIT` cubre la salida normal, el `exit 1` y la muerte por `set -e`. Las señales `INT`
(Ctrl+C) y `TERM` (`kill`) son las de la **Clase 9**.

## 8. El script integrador (el modelo a copiar)

Recorre un directorio de logs, cuenta errores por archivo, deja rastro en el journal,
limpia sus temporales y devuelve un código de salida honesto. Es el esqueleto de
cualquier script de mantenimiento que vas a escribir en tu vida.

```bash
#!/usr/bin/env bash
# mantenimiento_logs.sh — reporte de errores por archivo. Permisos sugeridos: 700.
set -euo pipefail

readonly TAG="mantenimiento"
readonly DIR_LOGS="${1:-/var/log/tienda}"
readonly UMBRAL="${2:-20}"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
trap 'log err "interrumpido"; exit 130' INT TERM

# --- log(): a la pantalla Y al journal del sistema -----------------------
log() {
    local nivel="$1"; shift
    printf '[%s] %s\n' "$nivel" "$*" >&2
    logger -t "$TAG" -p "user.${nivel}" "$*"
}

# --- validar(): cortar temprano y con un mensaje claro -------------------
validar() {
    [[ -n "$DIR_LOGS" ]]  || { log err "DIR_LOGS vacío"; return 2; }
    [[ -d "$DIR_LOGS" ]]  || { log err "no existe el directorio $DIR_LOGS"; return 2; }
    [[ -r "$DIR_LOGS" ]]  || { log err "sin permiso de lectura en $DIR_LOGS"; return 2; }
}

# --- contar_errores(): devuelve DATOS por stdout -------------------------
contar_errores() {
    local archivo="$1"
    grep -c '\[ERROR\]' "$archivo" || true    # grep -c devuelve 1 si no encuentra nada
}

main() {
    validar

    local archivo nombre n total=0 peor="" peor_n=0
    shopt -s nullglob

    for archivo in "$DIR_LOGS"/*.log; do       # glob, NO $(ls)
        nombre="$(basename "$archivo" .log)"
        n="$(contar_errores "$archivo")"
        total=$((total + n))
        printf '%-14s %4d\n' "$nombre" "$n" >> "$TMP"
        if (( n > peor_n )); then
            peor_n=$n
            peor="$nombre"
        fi
    done

    if [[ -z "$peor" ]]; then
        log warning "no encontré ningún .log en $DIR_LOGS"
        return 1
    fi

    sort -k2 -rn "$TMP"
    log info "total=${total} peor=${peor} (${peor_n} errores)"

    if (( total > UMBRAL )); then
        log err "umbral superado: ${total} > ${UMBRAL}"
        return 1
    fi
    return 0
}

main "$@"
```

Lo agendás con cron (ver `chuleta_cron.md`) y lo mirás con:

```bash
journalctl -t mantenimiento --since today --no-pager
```

## 9. Errores típicos

| Síntoma | Causa |
|---|---|
| El bucle ve un archivo partido en dos | `for f in $(ls)` + nombre con espacios |
| `$total` vale 0 después del `while` | el pipe creó un subshell |
| `$?` da 244 después de una función | usaste `return` con un número > 255 |
| Una función te cambió una variable del script | te faltó `local` |
| El bucle procesa un archivo llamado `*.log` | el glob no matcheó nada (`shopt -s nullglob`) |
| `rm` borró de más | `$DIR` vacío + `rm -rf "$DIR/"*`. Validá y probá con `echo` |
| El script se cuelga esperando | `read` sin `< archivo`: está leyendo del teclado |
| Se te mezcla el resultado con los mensajes | la función imprime mensajes a stdout, no a `>&2` |
