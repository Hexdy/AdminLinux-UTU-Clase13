# Playbooks de Ansible — AdminLinux Clase 13 (bucles + funciones y el reto de la bandera)

Un **escenario práctico de SRE**: desplegás un playbook de Ansible que te deja el material
del incidente (los logs de **todos** los hosts de una noche fea) y después, con lo que
viste de **bucles y funciones**, **escribís el script** que saca los tres números del
postmortem. Con esas 3 respuestas armás una **bandera** y la verificás con otro playbook.

> 🐧 Con una sola VM alcanza: todo corre contra `localhost` (grupo `[local]`).
> No es hacking: es la guardia normal de un SRE. Son demasiados archivos para mirarlos a
> mano — **para eso existe el `for`**.

## Paso 0 — ¿Tenés todo? (te dice qué falta y cómo instalarlo)

```bash
cd playbooks
bash comprobar_requisitos.sh
```

Detecta tu distro y, si falta algo (Ansible, Python, shellcheck), te da el comando exacto
para **apt**, **pacman** o **dnf**. De paso te dice cómo se llama el servicio de **cron en
tu distro** (`cron` vs `cronie` vs `crond`), que es la trampa multi-distro de esta clase.

## Paso 1 — Desplegá el reto

```bash
# Simular primero (no toca nada, buena costumbre):
ansible-playbook armar_reto.yml -l local --check --diff

# Aplicar de verdad (deja datos/reto/ listo):
ansible-playbook armar_reto.yml -l local
#   ↳ si al instalar shellcheck te pide contraseña de sudo, agregá  -K
```

Atajo que hace el preflight + el armado:

```bash
bash correr.sh
```

Esto deja tu misión en `../datos/reto/MISION.txt`. Leela:

```bash
cat ../datos/reto/MISION.txt
```

> 🔒 El playbook **no toca ningún servicio de tu máquina**. Lo único que hace con
> `systemctl` es un `is-enabled` de **lectura**, para mostrarte cómo se llama el cron en tu
> distro. No arranca, no habilita, no para nada. Y **no instala ningún cron job.**

## Paso 2 — Escribí el script que resuelve el postmortem

Te dejaron en `datos/reto/logs/`:

- `*.log` — el material del incidente (varios hosts).
- `viejos/` — material del **año pasado**: **no** es parte de este incidente.
- `notas.txt` — apuntes sueltos (**no** es un `.log`).
- `../nota_equipo.txt` — la nota del compañero (quedó en `0600`).

El jefe de guardia quiere 3 datos:

1. **R1** — total de líneas con el nivel `[ERROR]` **exacto**, sumando **todos** los
   `*.log` de esa carpeta (sin entrar a `viejos/`).
2. **R2** — qué archivo acumuló **más** `[ERROR]`, **sin** la extensión `.log`.
3. **R3** — dentro de **ese** archivo, cuántas veces aparece el `code=EXXX` **más
   repetido**.

Armá la bandera con el formato exacto: `BANDERA{<R1>-<R2>-<R3>}`.

> 💡 El script NO está acá a propósito: la idea es que lo escribas vos (el apunte y
> `docs/chuleta_bucles_funciones.md` te dan todas las piezas). Lo que sí te decimos son las
> **4 trampas**, porque son los errores clásicos:
>
> 1. Hay un archivo con un **espacio** en el nombre → `for f in $(ls)` te lo parte en dos.
> 2. `viejos/` tiene material del año pasado → `grep -r` te ensucia todo. Y adentro hay una
>    **bandera señuelo**: no sirve.
> 3. `notas.txt` menciona `[ERROR]` pero **no** es un `.log`.
> 4. Hay `[error]` en **minúscula** (ruido, no cuenta) y `[INFO]` que nombran la palabra
>    ERROR (tampoco).
>
> Si le pedís ayuda a una IA, **entendé el bucle** antes de correrlo.

## Paso 3 — Verificá tu bandera con Ansible

```bash
ansible-playbook comprobar_bandera.yml -e "bandera=BANDERA{...}"
```

- ✅ correcta → 🏁 trofeo.
- ❌ incorrecta → volvé a mirar cada número (y releé las 4 trampas).

El repo **no guarda la bandera en texto plano**: solo su huella **SHA-256** en
`secretos/bandera.sha256`. Es la misma idea con la que se guardan las contraseñas
(nunca el secreto, solo su hash). **Security by design.**

> 🗣️ Cuando te dé ✅, **se la decís al profe**. No hace falta Pull Request.

## Probá la idempotencia (lo más importante de Ansible)

Corré `armar_reto.yml` **dos veces seguidas**: la 1ª hace cambios (`changed`), la 2ª deja
todo en `ok` (`changed=0`, ya estaba como debía). Ese es el corazón de IaC: describís el
**estado deseado**, no pasos sueltos. Por eso las tareas de lectura llevan
`changed_when: false`: leer no es cambiar.

> 🔎 Guardate la idea: **tu script de hoy NO es idempotente** (si lo corrés dos veces,
> hace todo dos veces). La **Clase 14** va justo por ahí.

## 🔀 Multi-distro: el mismo playbook en 3 familias

| | Debian / Ubuntu | Arch | Fedora / RHEL |
|---|---|---|---|
| Gestor | `apt` | `pacman` | `dnf` |
| Paquete shellcheck | `shellcheck` | `shellcheck` | **`ShellCheck`** (CamelCase) |
| Detección | `ansible_os_family == 'Debian'` | `'Archlinux'` | `'RedHat'` |
| **Paquete de cron** | `cron` | `cronie` | `cronie` |
| **Unit de cron** | **`cron.service`** | **`cronie.service`** | **`crond.service`** |
| Log del demonio | `journalctl -u cron` | `journalctl -u cronie` | `journalctl -u crond` |

El playbook detecta la familia con `ansible_os_family` y el módulo genérico `package`
elige el gestor por vos. La instalación va envuelta en **`block`/`rescue`**: si no hay
sudo o no hay red, te avisa y **sigue** en vez de dejarte el laboratorio a medio armar.

## Qué hay acá

| Archivo | Qué es |
|---|---|
| `armar_reto.yml` | Despliega el material del incidente + shellcheck + tu misión (tri-distro, idempotente). |
| `comprobar_bandera.yml` | Verifica tu bandera por hash (sin exponer el secreto). |
| `comprobar_requisitos.sh` | Preflight: detecta tu distro y te dice qué instalar. |
| `correr.sh` | Atajo: preflight + arma el reto. |
| `templates/mision.txt.j2` | Plantilla Jinja de la misión (se personaliza con tus facts). |
| `reto/logs/*.log` | Los logs de la noche del incidente (uno por host). |
| `reto/logs/viejos/` | Material del año pasado: **no** cuenta (y trae un señuelo). |
| `reto/logs/notas.txt` | Apuntes sueltos que **no** son un `.log`. |
| `reto/nota_equipo.txt` | Nota del equipo (se deja en 0600). |
| `secretos/bandera.sha256` | Solo la **huella** de la bandera (no el secreto). |
| `inventory.ini` / `ansible.cfg` | Qué máquinas administra Ansible + config local. |

## ⚠️ Seguridad

- Ningún playbook usa `chmod 777`, contraseñas en texto plano ni secretos versionados.
- La nota con valor queda en **0600** (menor privilegio) por diseño.
- La bandera se guarda como **hash**, no en claro.
- Nada se arranca, se habilita ni se agenda en tu máquina: el único `systemctl` es de
  **lectura** y **no se instala ningún cron job**.
- Simulá (`--check --diff`) antes de aplicar algo que no conozcas.
