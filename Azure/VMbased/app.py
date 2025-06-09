from flask import Flask, request, render_template, session
from flask import redirect, url_for
import mysql.connector
import os

print("Running as UID:", os.getuid())

app = Flask(__name__)
app.secret_key = 'your-secret-key'  # Required for session

# Connect to Azure MySQL
try:
    conn = mysql.connector.connect(
        host=os.environ['DB_HOST'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASS'],
        database=os.environ['DB_NAME']
    )
    cursor = conn.cursor()
except mysql.connector.Error as err:
    print("Database connection failed:", err)
    exit(1)


@app.route('/', methods=['GET', 'POST'])
def index():
    if 'visits' in session:
        session['visits'] += 1
    else:
        session['visits'] = 1

    if request.method == 'POST':
        message = request.form['message'].strip()
        cursor.execute("INSERT INTO messages (message) VALUES (%s)", (message,))
        conn.commit()
        return redirect(url_for('index'))

    cursor.execute("SELECT id, message FROM messages ORDER BY id")
    messages = cursor.fetchall()

    return render_template('index.html', messages=messages, visits=session['visits'])

