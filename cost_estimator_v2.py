import json
import boto3

# Inicializar el cliente de AWS Pricing con boto3
pricing_client = boto3.client('pricing', region_name='us-east-1')

# Mapa de recursos soportados y sus ServiceCodes correspondientes
service_code_map = {
    "aws_instance": "AmazonEC2",
    "aws_s3_bucket": "AmazonS3",
    "aws_db_instance": "AmazonRDS",
    "aws_ebs_volume": "AmazonEBS",
    "aws_efs_file_system": "AmazonEFS",
    "aws_internet_gateway": "AmazonEC2",
    "aws_vpc": "AmazonEC2",
    "aws_subnet": "AmazonEC2",
    "aws_security_group": "AmazonEC2",
}

def get_aws_cost(resource_type, region='us-east-1'):
    """Obtiene el precio del recurso usando la API de AWS Pricing"""
    try:
        # Obtener el ServiceCode correspondiente al tipo de recurso
        service_code = service_code_map.get(resource_type, None)
        if not service_code:
            print(f"No se encontró el ServiceCode para el tipo de recurso: {resource_type}")
            return 0

        # Hacer una llamada a la API de AWS Pricing para obtener los filtros
        response = pricing_client.get_products(
            ServiceCode=service_code,
            Filters=[
                {
                    'Type': 'TERM_MATCH',
                    'Field': 'location',
                    'Value': region
                }
            ],
            MaxResults=1  # Limitar a un solo resultado
        )

        if not response['PriceList']:
            print(f"No se encontraron precios para {resource_type}")
            return 0

        price_list = json.loads(response['PriceList'][0])
        on_demand_price = price_list.get('terms', {}).get('OnDemand', {})

        if not on_demand_price:
            print(f"No se encontraron términos OnDemand para {resource_type}")
            return 0

        for key in on_demand_price:
            price_dimensions = on_demand_price[key].get('priceDimensions', {})
            for dim_key in price_dimensions:
                price_per_hour = price_dimensions[dim_key].get('pricePerUnit', {}).get('USD', 0)
                return float(price_per_hour) * 730  # Convertimos precio por hora a precio mensual (730 horas)

    except Exception as e:
        print(f"Error al obtener el precio de {resource_type}: {e}")
        return 0  # Si no se puede obtener el precio, devolvemos 0

def calculate_quantity(resource):
    """Calcula la cantidad de un recurso basado en su tipo."""
    resource_type = resource.get('type')

    if resource_type == "aws_instance":
        return 1
    elif resource_type == "aws_ebs_volume":
        # Obtener el tamaño del volumen de almacenamiento desde el plan Terraform
        return resource.get('change', {}).get('after', {}).get('size', 1)  # Tamaño en GB
    elif resource_type == "aws_efs_file_system":
        # Obtener el tamaño en bytes de EFS desde el plan Terraform (suponiendo que viene en 'size_in_bytes')
        size_in_bytes = resource.get('change', {}).get('after', {}).get('size_in_bytes', 0)
        return size_in_bytes / (1024 ** 3) if size_in_bytes > 0 else 500  # Convertir de bytes a GB, valor por defecto 500 GB
    else:
        # Para otros recursos, simplemente se cuenta 1 por recurso
        return 1

def calculate_monthly_cost(resource_type, count=1):
    """Calcula el costo mensual basado en el tipo de recurso y la cantidad"""
    cost_per_unit = get_aws_cost(resource_type)  # Usamos la función que llama a la API de AWS
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
                # Calcular la cantidad correcta de recursos
                resource_count = calculate_quantity(resource)
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
        print(f"  Cantidad: {details['count']:.2f}")  # Mostrar con 2 decimales si es necesario
        print(f"  Costo mensual estimado: ${details['estimated_monthly_cost']:.2f}")
        print("-" * 40)
    
    print(f"\nCosto total mensual estimado para todos los recursos: ${total_cost:.2f}")

if __name__ == "__main__":
    main()
