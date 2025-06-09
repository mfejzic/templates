import boto3
import os

def lambda_handler(event, context):
    # AWS services
    cost_explorer = boto3.client('ce')
    route53 = boto3.client('route53')

    # Replace with your AWS region
    region = 'your-region'

    # Replace with your EKS Fargate and EKS EC2 subnet IDs
    fargate_subnet_id = 'subnet-id-fargate'
    ec2_subnet_id = 'subnet-id-ec2'

    # Replace with your hosted zone ID and subdomain
    hosted_zone_id = 'your-hosted-zone-id'
    subdomain = 'your-subdomain.example.com'

    # Get cost data
    fargate_cost = get_subnet_cost(cost_explorer, region, fargate_subnet_id)
    ec2_cost = get_subnet_cost(cost_explorer, region, ec2_subnet_id)

    # Determine the more cost-efficient subnet
    cost_efficient_subnet = fargate_subnet_id if fargate_cost < ec2_cost else ec2_subnet_id

    # Update Route 53 record if the subnet has changed
    update_route53_record(route53, hosted_zone_id, subdomain, cost_efficient_subnet)

def get_subnet_cost(cost_explorer, region, subnet_id):
    response = cost_explorer.get_cost_and_usage(
        TimePeriod={
            'Start': '2023-01-01',
            'End': '2023-02-01',
        },
        Granularity='MONTHLY',
        Metrics=['UnblendedCost'],
        Filter={
            'Dimensions': {
                'SERVICE': ['Amazon Elastic Kubernetes Service'],
                'USAGE_TYPE': ['EKS-Fargate-BoxUsage', 'EKS-BoxUsage'],
                'LINKED_ACCOUNT': ['your-aws-account-id'],
                'REGION': [region],
                'RECORD_TYPE': ['Subnet'],
                'RECORD_ID': [subnet_id],
            },
        },
    )

    # Extract the unblended cost from the response
    cost_amount = float(response['ResultsByTime'][0]['Total']['UnblendedCost']['Amount'])

    return cost_amount

def update_route53_record(route53, hosted_zone_id, subdomain, subnet_id):
    response = route53.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch={
            'Changes': [{
                'Action': 'UPSERT',
                'ResourceRecordSet': {
                    'Name': f'{subdomain}.',
                    'Type': 'A',
                    'TTL': 300,
                    'ResourceRecords': [{'Value': get_subnet_ip_address(subnet_id)}],
                },
            }],
        },
    )

    print(f"Route 53 Record Updated: {response}")

def get_subnet_ip_address(subnet_id):
    ec2 = boto3.client('ec2')
    response = ec2.describe_subnets(SubnetIds=[subnet_id])
    return response['Subnets'][0]['CidrBlock'].split('/')[0]