import mysql.connector
import os

try:
    conn = mysql.connector.connect(
        host=os.environ['DB_HOST'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASS']
    )
    cursor = conn.cursor()

    cursor.execute("CREATE DATABASE IF NOT EXISTS myappdb")
    conn.database = os.environ['DB_NAME']

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.commit()
    print("Database and table setup complete.")

except mysql.connector.Error as err:
    print("Database initialization failed:", err)
    exit(1)

finally:
    if conn.is_connected():
        cursor.close()
        conn.close()
