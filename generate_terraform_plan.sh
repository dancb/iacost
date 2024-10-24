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

# Eliminar caracteres de color y caracteres especiales
# Guardar la salida limpia en un archivo temporal
CLEANED_PLAN_OUTPUT_FILE="cleaned_plan_output.txt"
sed -r "s/\x1b\[[0-9;]*m//g" "$PLAN_OUTPUT_FILE" > "$CLEANED_PLAN_OUTPUT_FILE"

# Verificar si el plan indica que no hay cambios o si hay recursos para destruir
if grep -q "Your infrastructure matches the configuration" "$CLEANED_PLAN_OUTPUT_FILE"; then
  echo -e "\n\nNo hay cambios para aplicar en la infraestructura.\n\n"
  CHANGES_DETECTED=0  # No hay cambios
elif grep -q "destroyed" "$CLEANED_PLAN_OUTPUT_FILE"; then
  echo -e "\n\nHay recursos para destruir en la infraestructura. Omitiendo ejecución del script Python.\n\n"
  CHANGES_DETECTED=2  # Hay recursos para destruir
else
  echo "Se detectaron cambios en la infraestructura."
  CHANGES_DETECTED=1  # Hay cambios que no implican destrucción
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
