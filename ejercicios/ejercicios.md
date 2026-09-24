# Ejercicios — Clase 13

Practicá en **tu VM** (nada de esto necesita `sudo`, salvo lo que diga) y sobre los
archivos de `datos/`. Las soluciones están en `soluciones.md`, pero **intentá primero**.

> 🧪 Antes de correr cualquier script: `bash -n script.sh` (sintaxis) y
> `shellcheck script.sh` (vicios). Para depurar, `bash -x script.sh`.
> Todos los scripts arrancan con `#!/usr/bin/env bash` + `set -euo pipefail` (Clase 12).

## Bucles

**1. `for` sobre un glob.**
Escribí `contar.sh` que recorra **todos** los `*.log` de `datos/` y para cada uno imprima,
alineado con `printf`, el nombre del archivo y su cantidad de líneas. Después contestá:
¿qué pasa si en `datos/` no hay ningún `.log`? ¿Cómo lo blindás?

**2. `while read` salteando comentarios.**
`datos/servicios.txt` tiene un servicio por línea, con comentarios (`#`) y alguna línea
vacía. Escribí `estado.sh` que recorra el archivo **línea por línea** y para cada servicio
real muestre `servicio: activo|inactivo` usando `systemctl is-active`. Los comentarios y
las vacías se saltean con `continue`.

**3. El bug del subshell.**
Este script imprime `total=0` aunque `datos/app_demo.log` tenga 40 líneas. Explicá **por
qué** y arreglalo **sin** usar `wc -l`.

```bash
total=0
cat datos/app_demo.log | while read -r linea; do
    total=$((total + 1))
done
echo "total=$total"
```

**4. Campos separados por `;`.**
`datos/hosts.txt` tiene `host;ip;ambiente`. Escribí `prod.sh` que muestre **solo** los
hosts de ambiente `prod`, en una tabla alineada `HOST | IP`. Pista: `IFS=';'` en el `read`.

## Arrays y funciones

**5. Arrays.**
Cargá `datos/servicios.txt` en un array con `mapfile -t`, imprimí **cuántos** elementos
tiene, el **primero**, el **último**, y después recorrelo con un `for` mostrando solo los
que **no** empiezan con `#`.

**6. Funciones (`local`, `return` vs `echo`).**
Escribí una función `contar_nivel <archivo> <nivel>` que devuelva **cuántas líneas** de ese
archivo tienen ese nivel entre corchetes (`[ERROR]`, `[WARN]`, `[INFO]`). Usala en un bucle
sobre `datos/app_demo.log` para los tres niveles.
Después respondé: si en vez de `echo` usaras `return "$n"`, ¿qué pasaría con un archivo de
**500** errores? ¿Y qué pasa si dentro de la función te olvidás el `local`?

**7. `trap` + `mktemp`.**
Escribí `reporte.sh` que arme un reporte en un archivo temporal creado con `mktemp`, lo
muestre ordenado y **lo borre siempre** al salir: termine bien, termine mal o lo cortes con
`Ctrl+C`. Probá las tres salidas y verificá con `ls /tmp` que no quedó basura.

## `logger` + `cron` + seguridad

**8. Que deje rastro y corra solo (y que sea seguro).**
a) Agregale al script del ejercicio 6 una función `log()` que escriba **a la pantalla
(stderr) y al journal** con `logger -t clase13`. Verificá con
`journalctl -t clase13 -n 10 --no-pager`.
b) Escribí la línea de `crontab` que lo corra **de lunes a viernes a las 07:15**, con ruta
absoluta y la salida redirigida a un log propio.
c) Una IA te propone esta línea. Marcá **tres** problemas y corregilos:

```
15 7 * * 1-5 mi_reporte.sh > /tmp/reporte-$(date +%F).txt
```

d) ¿Qué permisos le ponés al script y por qué **no** `777`? Si el script necesitara un
token de una API, ¿dónde lo guardás?

> 🤖 Si te trabás, pedile a la IA que te explique el bucle **línea por línea** y verificá
> con `head`/`less` sobre **un** archivo antes de confiar en el total. Y si te escribe un
> `rm` dentro de un `for`, **cambiá el `rm` por un `echo`** y mirá qué se expande antes de
> ejecutarlo de verdad.
