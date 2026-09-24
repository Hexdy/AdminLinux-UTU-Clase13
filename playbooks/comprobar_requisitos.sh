#!/usr/bin/env bash
# comprobar_requisitos.sh — ¿tenés todo para armar el reto con Ansible?
#
# Detecta tu distribución (Debian/Ubuntu, Arch, Fedora/RHEL) y, si algo falta,
# te dice el comando EXACTO para instalarlo. No instala nada por vos: solo
# comprueba y te guía (vos leés y corrés el comando con criterio).
#
# Uso:   bash comprobar_requisitos.sh
set -u

echo "=== Comprobando requisitos para el reto de bucles + funciones ==="

# --- 1) Detectar el gestor de paquetes de tu distro ----------------------
if command -v apt-get >/dev/null 2>&1; then
  GESTOR="apt"
  INSTALAR="sudo apt update && sudo apt install -y"
  PKG_SHELLCHECK="shellcheck"
  UNIT_CRON="cron.service"
  PKG_CRON="cron"
elif command -v pacman >/dev/null 2>&1; then
  GESTOR="pacman"
  INSTALAR="sudo pacman -Sy --needed"
  PKG_SHELLCHECK="shellcheck"
  UNIT_CRON="cronie.service"
  PKG_CRON="cronie"
elif command -v dnf >/dev/null 2>&1; then
  GESTOR="dnf"
  INSTALAR="sudo dnf install -y"
  PKG_SHELLCHECK="ShellCheck"   # ojo: en Fedora va con mayúsculas
  UNIT_CRON="crond.service"
  PKG_CRON="cronie"
else
  GESTOR="desconocido"
  INSTALAR=""
  PKG_SHELLCHECK="shellcheck"
  UNIT_CRON="cron.service / cronie.service / crond.service (fijate con: systemctl list-units '*cron*')"
  PKG_CRON="cron o cronie"
fi
echo "Distro / gestor de paquetes detectado: ${GESTOR}"
echo "En esta distro el servicio de cron se llama: ${UNIT_CRON}  (paquete: ${PKG_CRON})"
echo

# --- 2) Comprobar cada herramienta requerida -----------------------------
faltan=0

# $1 = comando a buscar, $2 = paquete a instalar si falta
comprobar() {
  local cmd="$1" pkg="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [OK]    ${cmd}  ->  $("$cmd" --version 2>&1 | head -n1)"
  else
    echo "  [FALTA] ${cmd}"
    if [ "$GESTOR" != "desconocido" ]; then
      echo "          instalalo con:  ${INSTALAR} ${pkg}"
    else
      echo "          gestor no reconocido; instalá '${pkg}' con el gestor de tu distro."
    fi
    faltan=$((faltan + 1))
  fi
}

comprobar ansible-playbook ansible
comprobar python3 python3
comprobar bash bash
# shellcheck lo instala el propio playbook (armar_reto.yml), pero si querés adelantarte:
comprobar shellcheck "$PKG_SHELLCHECK"

# --- 3) ¿Tenés logger y journalctl? (los usamos en la clase) -------------
echo
if command -v logger >/dev/null 2>&1; then
  echo "  [OK]    logger  ->  podés hacer que tus scripts dejen rastro en el journal"
else
  echo "  [AVISO] no encontré 'logger' (viene en util-linux o bsdutils). Instalalo si querés"
  echo "          practicar la parte de logs propios."
fi
if command -v journalctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  echo "  [OK]    journalctl + systemd  ->  podés leer lo que escribas con logger"
else
  echo "  [AVISO] no detecto systemd como PID 1 (¿WSL1, contenedor o initrd?)."
  echo "          El RETO igual se resuelve: son archivos de texto, no necesitan systemd."
fi

# --- 4) ¿Está el demonio de cron? (opcional para la clase) ---------------
echo
if command -v crontab >/dev/null 2>&1; then
  echo "  [OK]    crontab  ->  podés practicar 'crontab -l' y 'crontab -e'"
  echo "          (acordate: 'crontab -l > ~/crontab_respaldo.txt' ANTES de tocar nada)"
else
  echo "  [AVISO] no tenés 'crontab' instalado (pasa seguido en Arch y en Fedora mínimo)."
  echo "          Si querés practicar:  ${INSTALAR} ${PKG_CRON}"
  echo "          y después:            sudo systemctl enable --now ${UNIT_CRON}"
fi

# --- 5) Resumen ----------------------------------------------------------
echo
if [ "$faltan" -eq 0 ]; then
  echo "=== Todo listo. Armá el reto: ==="
  echo "    ansible-playbook armar_reto.yml -l local --check --diff   # simular"
  echo "    ansible-playbook armar_reto.yml -l local                  # aplicar"
  exit 0
else
  echo "=== Faltan ${faltan} requisito(s). Instalalos (arriba te digo cómo) y volvé a correr este script. ==="
  echo "    (Nota: 'shellcheck' también lo instala el playbook armar_reto.yml por vos.)"
  exit 1
fi
