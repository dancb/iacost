#!/bin/bash

# Habilitar la opción para fallar en caso de error
set -e
set -o pipefail

# Variables
PLAN_FILE="plan.tfplan"
OUTPUT_FILE="plan.json"

# Eliminar archivos si existen
if [ -f "$PLAN_FILE" ]; then
  echo "Eliminando archivo existente: $PLAN_FILE"
  rm "$PLAN_FILE"
fi

if [ -f "$OUTPUT_FILE" ]; then
  echo "Eliminando archivo existente: $OUTPUT_FILE"
  rm "$OUTPUT_FILE"
fi

# Ejecutar terraform plan y guardar la salida en un archivo binario
echo "Generando el archivo de plan de Terraform: $PLAN_FILE"
if terraform plan -out="$PLAN_FILE"; then
  echo "Exportando el archivo $PLAN_FILE a formato JSON: $OUTPUT_FILE"
  if terraform show -json "$PLAN_FILE" > "$OUTPUT_FILE"; then
    echo "El archivo $OUTPUT_FILE ha sido generado exitosamente."
  else
    echo "Error al convertir el archivo $PLAN_FILE a JSON."
    exit 1
  fi
else
  echo "Error al generar el archivo de plan de Terraform."
  exit 1
fi