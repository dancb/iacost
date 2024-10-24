#!/bin/bash

# Habilitar la opción para fallar en caso de error
set -e
set -o pipefail

# Variables
PLAN_FILE="plan.tfplan"
OUTPUT_FILE="plan.json"
CHANGES_DETECTED=0  # Inicializa una variable para detectar cambios

# Verificar si jq está instalado, si no lo está, instalarlo
if ! command -v jq &> /dev/null; then
  echo "jq no está instalado. Instalando jq..."
  # Detectar si el sistema usa apt (Debian/Ubuntu) o yum (RedHat/CentOS)
  if command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y jq
  elif command -v yum &> /dev/null; then
    sudo yum install -y jq
  else
    echo "No se pudo determinar el gestor de paquetes. Por favor, instala jq manualmente."
    exit 1
  fi
else
  echo "jq ya está instalado."
fi

# Eliminar archivos si existen
if [ -f "$PLAN_FILE" ]; then
  echo "Eliminando archivo existente: $PLAN_FILE"
  rm "$PLAN_FILE"
fi

if [ -f "$OUTPUT_FILE" ];then
  echo "Eliminando archivo existente: $OUTPUT_FILE"
  rm "$OUTPUT_FILE"
fi

# Ejecutar terraform plan y capturar la salida
echo "Generando el archivo de plan de Terraform: $PLAN_FILE"
PLAN_OUTPUT=$(terraform plan -out="$PLAN_FILE")

# Imprimir la salida de PLAN_OUTPUT
echo "------------------> Resultado de terraform plan:"
echo "$PLAN_OUTPUT"

# Verificar si el plan indica que no hay cambios
if echo "$PLAN_OUTPUT" | grep -q "No changes. Your infrastructure matches the configuration."; then
  echo "No hay cambios para aplicar en la infraestructura."
  CHANGES_DETECTED=0  # No hay cambios
else
  echo "Exportando el archivo $PLAN_FILE a formato JSON: $OUTPUT_FILE"
  if terraform show -json "$PLAN_FILE" > "$OUTPUT_FILE"; then
    echo "El archivo $OUTPUT_FILE ha sido generado exitosamente."
    CHANGES_DETECTED=1  # Hay cambios
  else
    echo "Error al convertir el archivo $PLAN_FILE a JSON."
    exit 1
  fi
fi

# Retorna el estado de cambios detectados
exit $CHANGES_DETECTED
