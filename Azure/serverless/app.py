import os
from flask import Flask, render_template, request, redirect, url_for, session                # flask lets you create website, redner_template serves HTML, request reads incoming data/input, redirect and url_for moves users page between pages, session traxks user specific data likenum of times they visited
from azure.cosmos import CosmosClient, exceptions                                            # main communicator with cosmos db server
import uuid                                                                                  # lets you create unique ID's

app = Flask(__name__)
app.secret_key = 'your-secret-key'                                                           # Needed for sessions (change to something secure)

print("[DEBUG] COSMOS_ENDPOINT:", os.environ.get('COSMOS_ENDPOINT'))                         # reveals what values are being loaded into your environment, need for troubleshooting
print("[DEBUG] COSMOS_DB_NAME:", os.environ.get('COSMOS_DB_NAME'))
print("[DEBUG] COSMOS_CONTAINER_NAME:", os.environ.get('COSMOS_CONTAINER_NAME'))


# Read Cosmos DB connection info from environment variables                                  # retrieves these values from the containers OS. Check the container_app block on main to find them
COSMOS_ENDPOINT = os.environ.get('COSMOS_ENDPOINT')
COSMOS_KEY = os.environ.get('COSMOS_KEY')                                                    # secret stored in key vault
COSMOS_DB_NAME = os.environ.get('COSMOS_DB_NAME')
COSMOS_CONTAINER_NAME = os.environ.get('COSMOS_CONTAINER_NAME')

# Initialize Cosmos client only if all env vars are present, else fallback to local mode     # checks these values are present before connecting to cosmos
if COSMOS_ENDPOINT and COSMOS_KEY and COSMOS_DB_NAME and COSMOS_CONTAINER_NAME:
    client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)                                       # client is main connection to cosmos, needs the endpoint and key
    database = client.get_database_client(COSMOS_DB_NAME)                                    # database is like a specific file drawer
    container = database.get_container_client(COSMOS_CONTAINER_NAME)                         # and container is like a specific folder
    print("Connected to Cosmos DB")
else:
    print("Cosmos DB config not found, running in local test mode.")                         # if connection fails, will set attributes to 'none', which prevents it from crashing
    client = None
    container = None

@app.route('/', methods=['GET', 'POST'])                                                     # 'GET' is when you load the page into a browser, 'POST' is when you submit a form
def index():
    if request.method == 'POST':                                                             # this line will run only if a form is submitted
        message = request.form.get('message')                                                # will pull the users message from the form
        print(f"Received message from form: {message}")  
        if message and container:                                                            # if message is valid and container exists, it will generate a unique number for the message, and place both in the database
            # Create unique id for partition key and item id
            message_id = str(uuid.uuid4())                                                   # this creates the unique ID
            item = {                                                                         # item{} will create a dictionary to store the ID and message
                'id': message_id,                                                            # Cosmos DB requires 'id' string as unique key
                'message': message                                                           # ID and message will be stored as JSON in the DB
            }
            try:
                container.create_item(body=item)                                             # this will try to save the item to cosmos DB
                print(f"Inserted item into Cosmos DB: {item}")  
            except exceptions.CosmosHttpResponseError as e:                                  # if cosmos rejects the item, it will catch the error and print the following
                print(f"Error inserting item: {e}")                                          # ^
        return redirect(url_for('index'))                                                    # will redirect user back to homepage after submitting form, this prevents them from resubmitting if they refresh the page
 
    # For GET, fetch all messages if connected to Cosmos
    # creates a new list to pull ID and message from 'item' - necessary because cosmos adds metadata to the dictionary, so we need a list with just ID and messages
    messages = []                                                                            # creates a new empty list called 'messages'
    if container:                                                                            # runs this block only if connected to cosmos and contatiner is available
        try:
            # Query all items in container
            items = container.read_all_items(max_item_count=100)                             # 'items' will store up to 100 documents/dicstionaries. each document contains the ID and message. 'items' will become an iterable, use this to loop through all dictionaries extracting the ID and message
            messages = [{"id": item["id"], "message": item["message"]} for item in items]    # for each dictionary/'item' in the list 'items', pull out the ID and message, put them in a new dictionary and add that dict to the 'messages' list
        except exceptions.CosmosHttpResponseError as e:                                      # exception will log any issues reading from cosmos
            print(f"Error reading items: {e}")                                               # 'e' will reveal the error
    else:
        # Local fallback messages
        messages = ["This is a placeholder message. Cosmos DB is not connected."]            # if cosmos fails to connect, it will return a default/dummy placeholder

    visits = session.get('visits', 0) + 1                                                    # tracks num of times user visited, session stored in browser cookies
    session['visits'] = visits

    return render_template('index.html', messages=messages, visits=visits)

if __name__ == '__main__':
    # Use port 80 if running in container, else default 5000
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)                                                       # allows to be accessed from outside the container

# or switch messages back to this # messages = [{"id": item["id"], "message": item["message"]} for item in items]
# session stores number in web cookies, not cosmos
    


# this flask app is like a postal office #
# - each visitor can drop of a message 
# - messages are saved in cosmos db (cloud filing cabinet)
# - every time you visit the office, you will see all the messages you dropped off, including the number of times you visited
# - if the office isnt available(lost connection), you will see a placeholder note
