from azure.cosmos import CosmosClient, PartitionKey
import os

# Get environment variables
COSMOS_ENDPOINT = os.environ['COSMOS_ENDPOINT']
COSMOS_KEY = os.environ['COSMOS_KEY']
DATABASE_NAME = os.environ['COSMOS_DB_NAME']
CONTAINER_NAME = os.environ['COSMOS_CONTAINER_NAME']

try:
    # Initialize Cosmos client
    client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)

    # Create database if not exists
    database = client.create_database_if_not_exists(id=DATABASE_NAME)

    # Create container if not exists with id as partition key
    container = database.create_container_if_not_exists(
        id=CONTAINER_NAME,
        partition_key=PartitionKey(path="/id"),
        offer_throughput=400
    )

    print("Cosmos DB database and container setup complete.")

except Exception as e:
    print("Cosmos DB initialization failed:", e)
    exit(1)
