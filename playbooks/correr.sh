#!/usr/bin/env bash
# correr.sh — atajo: comprueba requisitos y ARMA el reto (deja datos/reto/ listo).
# Provisionar archivos locales es seguro, así que este atajo aplica de una.
# Si querés ver antes qué haría sin tocar nada:
#     ansible-playbook armar_reto.yml -l local --check --diff
#
# Uso:   bash correr.sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# 1) ¿Tenés todo lo necesario? Si falta algo, corta acá y te dice cómo instalarlo.
bash "${DIR}/comprobar_requisitos.sh"

echo
echo "=== Armando el material del postmortem (datos/reto/logs/) ==="
# Si al instalar shellcheck te pide contraseña de sudo, corré a mano con -K:
#   ansible-playbook armar_reto.yml -l local -K
ansible-playbook "${DIR}/armar_reto.yml" -l local

echo
echo "Listo. Abrí la misión y escribí el script que saca los 3 datos:"
echo "    cat ../datos/reto/MISION.txt"
echo
echo "Cuando tengas la bandera, verificala:"
echo "    ansible-playbook comprobar_bandera.yml -e \"bandera=BANDERA{...}\""
