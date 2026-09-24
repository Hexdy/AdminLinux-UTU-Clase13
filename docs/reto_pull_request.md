# Reto de la semana — Clase 13 🏁 (la bandera)

Cerramos el bloque de scripting como en un trabajo real: **desplegás el entorno con
Ansible**, **escribís un script con bucles y funciones** que procese un montón de archivos,
capturás la **bandera** y **se la decís al profe**.

> 🐧 No es hacking: es el laburo normal de un SRE (te dejan 10 logs y querés saber qué
> host se rompió más). La bandera es la **recompensa** por hacerlo bien.

> 🏁 **Este reto NO se entrega por Pull Request.** No tenés que subir nada al repo: cuando
> tengas la bandera verificada, **se la decís al profe** (en clase o por el canal del
> curso). Eso es todo.

## El escenario

Anoche la plataforma de la tienda tuvo una noche fea. Te dejaron en una carpeta los logs
de **todos** los hosts y el jefe de guardia quiere tres números para el postmortem. Son
demasiados archivos para mirarlos a mano: **eso es exactamente para lo que existe un
bucle**.

## Pasos

1. **Cloná fuera de Drive**:
   ```bash
   git clone <url> C:\src\AdminLinux-UTU-Clase13
   cd C:\src\AdminLinux-UTU-Clase13\playbooks
   ```
2. **Desplegá el material con Ansible** (idempotente; simulá primero con `--check`):
   ```bash
   ansible-playbook armar_reto.yml -l local --check --diff
   ansible-playbook armar_reto.yml -l local
   ```
   Esto crea `datos/reto/logs/` con el material del incidente y te deja tu `MISION.txt`.
   Corré el playbook **dos veces**: la 2ª da `changed=0` (idempotencia).
3. **Escribí un script** (con `for`, una función y comillas) que conteste:
   - **R1** — total de líneas con el nivel `[ERROR]` **exacto**, sumando **todos** los
     `*.log` de `datos/reto/logs/`.
   - **R2** — el archivo que acumuló **más** `[ERROR]`, **sin** la extensión `.log`.
   - **R3** — dentro de **ese** archivo, cuántas veces aparece el `code=EXXX` **más
     repetido**.
4. **Armá la bandera** con el formato exacto y **verificala** con Ansible:
   ```bash
   ansible-playbook comprobar_bandera.yml -e "bandera=BANDERA{<R1>-<R2>-<R3>}"
   ```
   Tiene que dar **✅ BANDERA CORRECTA**.
5. **Decile la bandera al profe** — en clase o por el canal del curso. Con eso el reto
   queda entregado. **No hace falta subir nada al repo** ni abrir un Pull Request.

## Las trampas (avisadas)

Están puestas **a propósito**: son los 4 errores que comete todo el mundo la primera vez.

1. 🔴 **Hay un archivo con un ESPACIO en el nombre.** Si recorrés con `for f in $(ls)` se
   te parte en dos y contás de menos. Recorré con **glob** y entrecomillá: `"$f"`.
2. 🔴 **Hay un subdirectorio `viejos/`** con el material del **año pasado**. **No** es
   parte de este incidente. Si grepeás **recursivo** (`grep -r`) te ensucia los tres
   números. Y adentro hay una `BANDERA{...}` vieja: es un **señuelo**, no sirve.
3. 🔴 **Hay un `notas.txt`** que menciona `[ERROR]` pero **no es un `.log`**. Tu bucle
   tiene que procesar `*.log`, no todo lo que haya en la carpeta.
4. 🔴 **Mayúsculas**: hay líneas `[error]` en minúscula (ruido de una librería, **no** son
   fallos) y líneas `[INFO]` que nombran la palabra `ERROR` en un resumen. Contá el nivel
   `[ERROR]` con corchetes y **sin** `grep -i`.

## Cómo se evalúa (autoevaluación)

- [ ] Desplegaste con `armar_reto.yml` y lo corriste **2 veces** (la 2ª da `changed=0`).
- [ ] Leíste la `MISION.txt` que te generó el playbook con **tus** facts.
- [ ] Tu bucle usa **glob** (`for f in "$DIR"/*.log`), no `$(ls)`, y usa `"$f"`.
- [ ] Tenés al menos **una función** (por ejemplo `contar_errores`) que devuelve el dato
      por `echo` y lo capturás con `$(...)`.
- [ ] El acumulador **no** está adentro de un `cmd | while` (si no, te da 0).
- [ ] **R1** cuenta `[ERROR]` exacto, sin `-i`, sin recursión y **con** el archivo del
      nombre con espacio.
- [ ] **R2** va **sin** el `.log` y es el archivo con **más** errores (no el más largo).
- [ ] **R3** mira solo el archivo de R2 y cuenta el **código** más repetido.
- [ ] `comprobar_bandera.yml` te dio ✅.
- [ ] Le **dijiste la bandera al profe**.

## Extra (opcional, sube nota de orgullo)

- Que tu script deje rastro con `logger -t clase13` y mirarlo con `journalctl -t clase13`.
- Proponer la línea de `crontab` que lo correría todas las mañanas a las 07:15 — con ruta
  absoluta y la salida redirigida.
- Pasarlo por `shellcheck` sin advertencias.

> 🔒 El repo no guarda la bandera en claro, solo su **hash SHA-256**. Así se guardan las
> contraseñas de verdad: nunca el secreto, solo su huella.

> 🤖 Si le pedís el bucle a la IA, revisá que **no** use `$(ls)`, que entrecomille la
> variable y que no grepee recursivo. Una IA te tira `for f in $(ls *.log)` sin pestañear,
> y con este material ese bucle te da el número **equivocado**.
