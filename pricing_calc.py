import json
import boto3

# Constante global para la región
US_EAST_N_VIRGINIA = 'US East (N. Virginia)'

# Inicializa el cliente de AWS Pricing
pricing_client = boto3.client('pricing', region_name='us-east-1')

def get_aws_cost(service_code, filters):
    """Obtiene el precio usando la API de AWS Pricing"""
    try:
        response = pricing_client.get_products(ServiceCode=service_code, Filters=filters, MaxResults=1)
        
        if not response['PriceList']:
            print(f"No se encontraron precios para los filtros: {filters}")
            return 0

        price_list = json.loads(response['PriceList'][0])
        on_demand_terms = price_list['terms']['OnDemand']
        for term_key in on_demand_terms:
            price_dimensions = on_demand_terms[term_key]['priceDimensions']
            for dim_key in price_dimensions:
                price_per_hour = price_dimensions[dim_key]['pricePerUnit']['USD']
                return float(price_per_hour) * 730  # Convertir a costo mensual (730 horas al mes)
    except Exception as e:
        print(f"Error al obtener el precio: {e}")
        return 0

def estimate_ec2_cost(resource_data):
    """Calcula el costo mensual de una instancia EC2 basada en el plan de Terraform"""
    instance_type = resource_data['change']['after']['instance_type']
    operating_system = resource_data['change']['after'].get('operating_system', 'Linux')  # Asume Linux si no está definido
    tenancy = resource_data['change']['after'].get('tenancy', 'Shared')
    capacity_status = resource_data['change']['after'].get('capacity_status', 'Used')

    # Establece el valor para location (puedes ajustarlo si el plan incluye más información)
    location = 'US East (N. Virginia)'

    filters = [
        {'Type': 'TERM_MATCH', 'Field': 'instanceType', 'Value': instance_type},
        {'Type': 'TERM_MATCH', 'Field': 'location', 'Value': location},
        {'Type': 'TERM_MATCH', 'Field': 'operatingSystem', 'Value': operating_system},
        {'Type': 'TERM_MATCH', 'Field': 'preInstalledSw', 'Value': 'NA'},
        {'Type': 'TERM_MATCH', 'Field': 'tenancy', 'Value': tenancy},
        {'Type': 'TERM_MATCH', 'Field': 'capacitystatus', 'Value': capacity_status}
    ]
    
    return get_aws_cost('AmazonEC2', filters)

def estimate_ebs_cost(resource_data):
    """Calcula el costo mensual de un volumen EBS usando los datos del plan de Terraform"""
    volume_size = resource_data['change']['after']['size']
    volume_type = resource_data['change']['after'].get('volume_type', 'gp2')
    location = resource_data['change']['after'].get('availability_zone', 'us-east-1')
    
    location_mapped = map_location_to_pricing(location)
    
    filters = [
        {'Type': 'TERM_MATCH', 'Field': 'volumeType', 'Value': volume_type},
        {'Type': 'TERM_MATCH', 'Field': 'location', 'Value': location_mapped}
    ]
    price_per_gb = get_aws_cost('AmazonEBS', filters)
    return price_per_gb * volume_size

def estimate_elastic_ip_cost(resource_data):
    """Calcula el costo mensual de una Elastic IP (si está presente en el plan de Terraform)"""

    filters = [
        {'Type': 'TERM_MATCH', 'Field': 'location', 'Value': US_EAST_N_VIRGINIA},
        {'Type': 'TERM_MATCH', 'Field': 'productFamily', 'Value': 'Elastic IP'}
    ]
    
    # Considera que AWS cobra solo si la EIP no está asociada a una instancia
    return get_aws_cost('AmazonEC2', filters)

def map_location_to_pricing(availability_zone):
    """Mapea el availability_zone a una región de precios"""
    region_mapping = {
        'us-east-1a': US_EAST_N_VIRGINIA,
        'us-east-1b': US_EAST_N_VIRGINIA,
        'us-east-1c': US_EAST_N_VIRGINIA,
        'us-east-1d': US_EAST_N_VIRGINIA,
        'us-east-1e': US_EAST_N_VIRGINIA,
        'us-east-1f': US_EAST_N_VIRGINIA
    }
    return region_mapping.get(availability_zone, US_EAST_N_VIRGINIA)

def parse_terraform_plan(json_file):
    """Parsea el archivo plan.json de Terraform y estima los costos de EC2 y EBS"""
    with open(json_file, 'r') as f:
        terraform_data = json.load(f)

        total_cost = 0

        # Delimitador llamativo para el inicio del bloque de precios
        print("\n" + "#" * 80)
        print("###" + " " * 25 + "INICIO DE LOS COSTOS DE LOS RECURSOS" + " " * 25 + "###")
        print("#" * 80)
        print("#" * 80 + "\n")

        for resource in terraform_data.get('resource_changes', []):
            if resource['type'] == 'aws_instance':
                ec2_cost = estimate_ec2_cost(resource)
                total_cost += ec2_cost
                print(f"Instancia EC2: ${ec2_cost:.2f} mensual")
            
            if resource['type'] == 'aws_ebs_volume':
                ebs_cost = estimate_ebs_cost(resource)
                total_cost += ebs_cost
                print(f"Volumen EBS: ${ebs_cost:.2f} mensual")

            if resource['type'] == 'aws_eip':
                eip_cost = estimate_elastic_ip_cost(resource)
                total_cost += eip_cost
                print(f"Elastic IP: ${eip_cost:.2f} mensual")

        print(f"\nCosto total estimado: ${total_cost:.2f} mensual")

        # Delimitador llamativo para el final del bloque de precios
        print("\n" + "#" * 80)
        print("###" + " " * 27 + "FIN DE LOS COSTOS DE LOS RECURSOS" + " " * 27 + "###")
        print("#" * 80)
        print("#" * 80 + "\n")

if __name__ == "__main__":
    # Reemplaza con la ruta a tu archivo plan.json
    parse_terraform_plan('plan.json')
