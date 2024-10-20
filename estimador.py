import json

# Tabla de costos estimados (simplificada)
# Estos son valores de ejemplo. Deben actualizarse con los costos reales del proveedor cloud.
cost_table = {
    "aws_instance": 50,  # Costo mensual estimado para una instancia EC2
    "aws_s3_bucket": 5,  # Costo mensual estimado para un bucket S3
    "aws_db_instance": 100,  # Costo mensual estimado para una instancia RDS
    # Agregar más tipos de recursos y sus costos estimados aquí
}

def calculate_monthly_cost(resource_type, count=1):
    """Calcula el costo mensual basado en el tipo de recurso y la cantidad"""
    cost_per_unit = cost_table.get(resource_type, 0)  # Si no está en la tabla, costo es 0
    return cost_per_unit * count

def parse_terraform_plan(json_file):
    """Lee el archivo JSON generado por Terraform plan y calcula los costos"""
    total_cost = 0
    resource_costs = {}

    with open(json_file, 'r') as f:
        terraform_data = json.load(f)

        # Navegar por los recursos en el plan Terraform
        for resource in terraform_data.get('resource_changes', []):
            resource_type = resource.get('type')
            resource_name = resource.get('name')
            change_action = resource.get('change', {}).get('actions', [])
            
            if 'create' in change_action:
                resource_count = len(resource.get('change', {}).get('after', [])) or 1
                resource_estimated_cost = calculate_monthly_cost(resource_type, resource_count)
                
                # Sumar al total
                total_cost += resource_estimated_cost
                
                # Almacenar el costo de cada recurso
                resource_costs[resource_name] = {
                    'type': resource_type,
                    'count': resource_count,
                    'estimated_monthly_cost': resource_estimated_cost
                }

    return total_cost, resource_costs

def main():
    json_file = 'plan.json'  # Asegúrate de que el archivo esté en el mismo directorio
    total_cost, resource_costs = parse_terraform_plan(json_file)

    # Mostrar los resultados
    print("\nEstimación de costos mensuales por recursos:\n")
    for resource_name, details in resource_costs.items():
        print(f"Recurso: {resource_name}")
        print(f"  Tipo: {details['type']}")
        print(f"  Cantidad: {details['count']}")
        print(f"  Costo mensual estimado: ${details['estimated_monthly_cost']:.2f}")
        print("-" * 40)
    
    print(f"\nCosto total mensual estimado para todos los recursos: ${total_cost:.2f}")

if __name__ == "__main__":
    main()
