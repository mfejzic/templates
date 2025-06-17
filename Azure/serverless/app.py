from flask import Flask, request, render_template, session, redirect, url_for
import os
import uuid
from azure.cosmos import CosmosClient, PartitionKey

app = Flask(__name__)
app.secret_key = 'your-secret-key'  # Required for session

# Cosmos DB config from environment variables
COSMOS_ENDPOINT = os.environ['COSMOS_ENDPOINT']
COSMOS_KEY = os.environ['COSMOS_KEY']
COSMOS_DB_NAME = os.environ['COSMOS_DB_NAME']
COSMOS_CONTAINER_NAME = os.environ['COSMOS_CONTAINER_NAME']

# Create Cosmos DB client and container
client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
database = client.create_database_if_not_exists(id=COSMOS_DB_NAME)
container = database.create_container_if_not_exists(
    id=COSMOS_CONTAINER_NAME,
    partition_key=PartitionKey(path="/id"),
    offer_throughput=400
)

@app.route('/', methods=['GET', 'POST'])
def index():
    if 'visits' in session:
        session['visits'] += 1
    else:
        session['visits'] = 1

    if request.method == 'POST':
        message = request.form['message'].strip()
        message_doc = {
            'id': str(uuid.uuid4()),
            'message': message
        }
        container.create_item(body=message_doc)
        return redirect(url_for('index'))

    query = "SELECT c.id, c.message FROM c"
    messages = list(container.query_items(
        query=query,
        enable_cross_partition_query=True
    ))

    return render_template('index.html', messages=messages, visits=session['visits'])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
