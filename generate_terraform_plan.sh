#!/bin/bash

# Habilitar la opción para fallar en caso de error
set -e
set -o pipefail

# Variables
PLAN_FILE="plan.tfplan"
PLAN_OUTPUT_FILE="plan_output.txt"
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

if [ -f "$OUTPUT_FILE" ]; then
  echo "Eliminando archivo existente: $OUTPUT_FILE"
  rm "$OUTPUT_FILE"
fi

if [ -f "$PLAN_OUTPUT_FILE" ]; then
  echo "Eliminando archivo existente: $PLAN_OUTPUT_FILE"
  rm "$PLAN_OUTPUT_FILE"
fi

# Ejecutar terraform plan y guardar la salida en un archivo binario
echo "Generando el archivo de plan de Terraform: $PLAN_FILE"
terraform plan -out="$PLAN_FILE"

# Mostrar el contenido del plan y guardarlo en un archivo de texto para análisis
echo "Mostrando el plan de Terraform y guardándolo en $PLAN_OUTPUT_FILE"
terraform show "$PLAN_FILE" | tee "$PLAN_OUTPUT_FILE"

# Imprimir el contenido del archivo de salida del plan
echo "Contenido del archivo de salida del plan ($PLAN_OUTPUT_FILE):"
cat "$PLAN_OUTPUT_FILE"

# Verificar si el plan indica que no hay cambios o si tiene recursos a destruir
if grep -q "Your infrastructure matches the configuration" "$PLAN_OUTPUT_FILE"; then
  echo "No hay cambios para aplicar en la infraestructura."
  CHANGES_DETECTED=0  # No hay cambios
elif grep -q "destroy" "$PLAN_OUTPUT_FILE"; then
  echo "Hay recursos para destruir en la infraestructura."
  CHANGES_DETECTED=1  # Hay cambios
else
  echo "Se detectaron cambios en la infraestructura."
  CHANGES_DETECTED=1  # Hay cambios
fi

# Si hay cambios, exportar el archivo a formato JSON
if [ $CHANGES_DETECTED -eq 1 ]; then
  echo "Exportando el archivo $PLAN_FILE a formato JSON: $OUTPUT_FILE"
  if terraform show -json "$PLAN_FILE" > "$OUTPUT_FILE"; then
    echo "El archivo $OUTPUT_FILE ha sido generado exitosamente."
  else
    echo "Error al convertir el archivo $PLAN_FILE a JSON."
    exit 1
  fi
fi

# Retorna el estado de cambios detectados
exit $CHANGES_DETECTED
