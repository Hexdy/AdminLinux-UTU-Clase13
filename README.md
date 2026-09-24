# AdminLinux · UTU · Clase 13 — Shell scripting II (bucles, funciones, logs propios y tareas automáticas)

> Repo de la **Clase 13** de *Administración de Sistemas Linux* (UTU, 2026).
> Docente: **Ulyses García**. Repositorio **privado** de práctica.

Doble uso: 🤖 pegá `CONTEXTO_IA.md` en tu chatbot · 🧑‍💻 cloná y escribí scripts de verdad
sobre los `datos/` y sobre tu VM.

## 🚀 Arranque rápido

> 🔑 Cloná **fuera** de Google Drive / OneDrive. El sync corrompe `.git`.

```bash
git clone <url-de-este-repo> C:\src\AdminLinux-UTU-Clase13
cd C:\src\AdminLinux-UTU-Clase13

# Tu primer bucle de la clase (no borra nada, solo muestra):
for f in datos/*.log; do echo "== $f =="; grep -c '\[ERROR\]' "$f"; done

# Tu primer rastro en el journal:
logger -t clase13 -p user.info "arranqué la clase 13"
journalctl -t clase13 -n 5 --no-pager
```

## 🏁 El reto de la bandera ya está esperándote

El plato fuerte vive en [`playbooks/`](playbooks/README.md) y **se resuelve escribiendo un
script con bucles y funciones**:

1. **Desplegás** el material del incidente con Ansible:
   `ansible-playbook armar_reto.yml -l local` (multi-distro, idempotente).
2. **Escribís un script** que recorra **todos** los logs de `datos/reto/logs/`, cuente por
   archivo y saque tres números: cuántos errores hubo en total, qué host falló más y qué
   código de error se le repite a ese host.
3. **Armás** `BANDERA{<R1>-<R2>-<R3>}` y la **verificás** con
   `ansible-playbook comprobar_bandera.yml -e "bandera=BANDERA{...}"`.

> 🗣️ **La bandera NO se entrega por Pull Request**: cuando te da ✅, **se la decís al
> profe** en clase o por el canal del curso.

> ⚠️ Hay **trampas puestas a propósito** (un archivo con espacio en el nombre, un
> subdirectorio con material viejo, niveles en minúscula y hasta una bandera **señuelo**).
> Si tu bucle está mal escrito, te da un número que *parece* bien. Leé `MISION.txt`.

## 🗂️ Qué hay acá

| Carpeta / archivo | Qué es |
|---|---|
| `CONTEXTO_IA.md` | **Pegá esto en tu chatbot** para que te asista con contexto de la clase. |
| `datos/app_demo.log` | Log chico para practicar `while read` sin tocar nada del sistema. |
| `datos/servicios.txt` | Lista de servicios (con comentarios) para practicar bucles + `continue`. |
| `datos/hosts.txt` | Inventario `host;ip;ambiente` para practicar `IFS=';'`. |
| `docs/chuleta_bucles_funciones.md` | Chuleta de `for`/`while`/arrays/funciones/`trap` + el script integrador completo. |
| `docs/chuleta_cron.md` | Los 5 campos, atajos, las 4 trampas de cron y cómo depurarlo. |
| `docs/reto_pull_request.md` | 🏁 El reto de la bandera explicado paso a paso. |
| `ejercicios/` | 8 ejercicios + soluciones comentadas. |
| `playbooks/` | 🏁 **El reto**: Ansible te arma el incidente, vos escribís el script que lo resuelve. |

## 🧵 Hilo del curso

En la **Clase 12** tu script aprendió a **decidir** (`if`, `case`, códigos de salida,
`set -euo pipefail`). Hoy le agregamos las otras tres patas de un script profesional:

```
   decide (C12)  +  REPITE (for/while)  +  SE ORDENA (funciones)  +  CORRE SOLO (cron)
```

Y encima le enseñamos a **dejar rastro** (`logger` → lo leés con `journalctl -t`, como en la
Clase 10). La **Clase 14** da el salto siguiente: tu script automatiza **en el tiempo**,
Ansible automatiza **en escala**.

## 🎯 Los 5 pilares

Hoy pega fuerte **Security by Design** (permisos `700`, cero secretos en el script,
`mktemp` + `trap`, validar antes de iterar, cron con usuario dedicado) e **IA aplicada**
(pedirle una línea de cron a un LLM y verificarla: ¿rutas absolutas? ¿redirige la salida?
¿el día de semana es el que creés?). El reto de [`playbooks/`](playbooks/README.md) suma
**IaC + Ansible** y **GitHub**.

## ⚠️ Seguridad (lo que se lleva plata en una auditoría)

- Un script que corre por `cron` **como root** y hace `rm -rf "$DIR/"*` con `$DIR` vacío
  te borra medio sistema. Validá **antes** del bucle y probá con `echo` primero.
- Un secreto adentro del script lo lee **cualquiera** que tenga permiso de lectura. Va en
  un archivo aparte con permisos `600`, o en una variable de entorno.
- Permisos del script: `700` (o `750` si lo comparte un grupo). **Nunca `777`.**
- Temporales con `mktemp` + `trap 'rm -f "$TMP"' EXIT` — no con nombres fijos en `/tmp`.

## 🐧 Multi-distro: el servicio de cron se llama distinto

| | Debian / Ubuntu | Arch | Fedora / RHEL |
|---|---|---|---|
| Paquete | `cron` | `cronie` | `cronie` |
| Unit | `cron.service` | `cronie.service` | `crond.service` |
| Log del demonio | `journalctl -u cron` | `journalctl -u cronie` | `journalctl -u crond` |

La **sintaxis del crontab es idéntica** en las tres. Si te dice "unit not found", antes de
asustarte: `systemctl list-units '*cron*'`.

---

## ❓ Autoevaluación de la clase

> 5 preguntas para saber si **entendiste lo de hoy**. No hay soluciones — pensalas y, si te
> trabás, abrí la 💡 **Pista**.

### 1️⃣ El bucle que se parte solo
Escribís `for f in $(ls *.log); do wc -l $f; done` y en el directorio hay un archivo que se
llama `app viejo.log`. ¿Qué pasa exactamente y cómo se escribe bien ese bucle?
<details><summary>💡 Pista</summary>

Bash parte la salida de un comando por **espacios**, no por líneas: ese nombre se convierte
en **dos** palabras. La forma correcta no usa ningún comando para listar — se lo pedís
directo al shell, y la variable se usa entre comillas.
</details>

### 2️⃣ La variable amnésica
Este script imprime `total=0` aunque el archivo tenga 300 líneas. ¿Por qué?

```bash
total=0
cat app.log | while read -r linea; do
    total=$((total + 1))
done
echo "total=$total"
```
<details><summary>💡 Pista</summary>

Cada lado de un `|` corre en su **propio proceso hijo**. El hijo puede leer lo que había,
pero lo que escribe se muere con él. No hay truco raro: hay que lograr que el bucle corra
en **tu** shell y no en un hijo. ¿Hace falta el pipe para darle de comer?
</details>

### 3️⃣ `return` no devuelve lo que creés
Escribís una función que cuenta líneas y termina con `return $n`. Con un archivo de 500
líneas, `$?` te da `244`. ¿Qué pasó y cómo devolvés el número de verdad?
<details><summary>💡 Pista</summary>

Ese valor no es un dato: es un **código de estado**, y vive en un solo byte. Fijate qué
número da `500 - 256`. Para devolver **datos** se usa otro camino: la función los escribe y
quien la llama los captura.
</details>

### 4️⃣ El cron fantasma
Tu script anda perfecto si lo corrés a mano, pero por `crontab` no hace nada y en el log
del sistema no aparece ningún error tuyo. Nombrá **dos** causas probables y cómo las
verificás.
<details><summary>💡 Pista</summary>

Cron no es tu terminal: arranca con un entorno **casi vacío** (mirá qué `PATH` tiene) y
**nadie está mirando** lo que tu script imprime. Dos costumbres arreglan el 90 % de estos
casos: una tiene que ver con **cómo nombrás los comandos y los archivos**, la otra con
**dónde va a parar la salida**.
</details>

### 5️⃣ Seguridad + IA
Una IA te propone esta línea de crontab para limpiar temporales:

```
0 3 * * * rm -rf /var/tmp/cache/*
```

Marcá **tres** problemas y cómo los arreglarías antes de instalarla.
<details><summary>💡 Pista</summary>

Uno es de **PATH** (¿está seguro de qué binario ejecuta?). Otro es de **evidencia**: si eso
falla a las 3 AM, ¿quién se entera? Y el tercero es el más caro: ese `*` depende de que la
ruta exista y no esté vacía — probá a reemplazar el borrado por un `echo` y mirá qué se
expande.
</details>

---

*Material docente. Elaborado con asistencia de IA y revisado por el docente.*
