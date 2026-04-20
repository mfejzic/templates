from flask import Flask, request, jsonify, render_template
import mysql.connector
import os
import logging
from logging.handlers import RotatingFileHandler

# ----------------------------
# LOGGING CONFIGURATION
# ----------------------------

# Create logger
logger = logging.getLogger()

logger.setLevel(logging.INFO)

# Create log format
formatter = logging.Formatter(
    "%(asctime)s [%(levelname)s] %(message)s"
)

# Console handler (Docker logs)
console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)

# File handler (writes to app.log)
file_handler = RotatingFileHandler(
    "app.log",
    maxBytes=10 * 1024,  # 10KB
    backupCount=3
)
file_handler.setFormatter(formatter)

# Add handlers
logger.addHandler(console_handler)
logger.addHandler(file_handler)


app = Flask(__name__)

# ----------------------------
# 1. DATABASE CONFIG
# ----------------------------
db_config = {
    "host": os.getenv("DB_HOST", "db"),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", "secret123"),
    "database": os.getenv("DB_NAME", "testdb")
}

# ----------------------------
# 2. FUNCTION TO CONNECT DB
# ----------------------------
def get_connection():
    try:
        conn = mysql.connector.connect(**db_config)
        logger.info("Database connection successful")
        return conn

    except mysql.connector.Error as err:
        logger.error(f"Database connection failed: {err}")
        raise

# ----------------------------
# 3. HEALTH CHECK ROUTE
# ----------------------------
@app.route("/")
def home():
    return "Flask + MySQL is running"

# ----------------------------
# 4. ROUTE TO FORM PAGE
# ----------------------------
@app.route("/form")
def form():
    return render_template("form.html")

# ----------------------------
# 5. ADD USER (CREATE)
# ----------------------------
@app.route("/add", methods=["POST"])
def add_user():
    name = request.form.get("name")

    logging.info(f"Received request to add user: {name}")

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "INSERT INTO users (name) VALUES (%s)",
        (name,)
    )

    conn.commit()

    logging.info(f"User successfully added to database: {name}")

    cursor.close()
    conn.close()

    return "User added"
    
# ----------------------------
# 6. GET USERS (READ)
# ----------------------------
@app.route("/users", methods=["GET"])
def get_users():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users")
    rows = cursor.fetchall()

    cursor.close()
    conn.close()

    return jsonify(rows)

# ----------------------------
# 7. RUN APP
# ----------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)