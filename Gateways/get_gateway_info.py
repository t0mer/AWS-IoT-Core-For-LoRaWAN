import boto3, json
from loguru import logger

session = boto3.Session(profile_name='', region_name='eu-west-1')
client = session.client('iotwireless')

response = client.get_wireless_gateway(
    Identifier='',
    IdentifierType='GatewayEui'
)


print(response)

