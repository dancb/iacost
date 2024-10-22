import json
import boto3

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

def estimate_ec2_cost(instance_type):
    """Calcula el costo mensual de una instancia EC2"""
    filters = [
        {'Type': 'TERM_MATCH', 'Field': 'instanceType', 'Value': instance_type},
        {'Type': 'TERM_MATCH', 'Field': 'location', 'Value': 'US East (N. Virginia)'},
        {'Type': 'TERM_MATCH', 'Field': 'operatingSystem', 'Value': 'Linux'},
        {'Type': 'TERM_MATCH', 'Field': 'preInstalledSw', 'Value': 'NA'},
        {'Type': 'TERM_MATCH', 'Field': 'tenancy', 'Value': 'Shared'},
        {'Type': 'TERM_MATCH', 'Field': 'capacitystatus', 'Value': 'Used'}
    ]
    return get_aws_cost('AmazonEC2', filters)

def estimate_ebs_cost(volume_size, volume_type='gp2'):
    """Calcula el costo mensual de un volumen EBS"""
    filters = [
        {'Type': 'TERM_MATCH', 'Field': 'volumeType', 'Value': volume_type},
        {'Type': 'TERM_MATCH', 'Field': 'location', 'Value': 'US East (N. Virginia)'}
    ]
    price_per_gb = get_aws_cost('AmazonEBS', filters)
    return price_per_gb * volume_size

def parse_terraform_plan(json_file):
    """Parsea el archivo plan.json de Terraform y estima los costos de EC2 y EBS"""
    with open(json_file, 'r') as f:
        terraform_data = json.load(f)

        total_cost = 0
        for resource in terraform_data.get('resource_changes', []):
            if resource['type'] == 'aws_instance':
                instance_type = resource['change']['after']['instance_type']
                ec2_cost = estimate_ec2_cost(instance_type)
                total_cost += ec2_cost
                print(f"Instancia EC2 ({instance_type}): ${ec2_cost:.2f} mensual")
            
            if resource['type'] == 'aws_ebs_volume':
                volume_size = resource['change']['after']['size']
                volume_type = resource['change']['after'].get('volume_type', 'gp2')
                ebs_cost = estimate_ebs_cost(volume_size, volume_type)
                total_cost += ebs_cost
                print(f"Volumen EBS ({volume_size} GB, {volume_type}): ${ebs_cost:.2f} mensual")
        
        print(f"\nCosto total estimado: ${total_cost:.2f} mensual")

if __name__ == "__main__":
    # Reemplaza con la ruta a tu archivo plan.json
    parse_terraform_plan('plan.json')
