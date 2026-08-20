import os
import time

import mysql.connector
from flask import Flask, jsonify, request


app = Flask(__name__)


DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_NAME = os.getenv("DB_NAME", "nimbuscart")
DB_USER = os.getenv("DB_USER", "nimbus")
DB_PASSWORD = os.getenv("DB_PASSWORD", "nimbuspass")


def get_db_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )


def initialize_database():
    create_table_query = """
    CREATE TABLE IF NOT EXISTS products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        stock INT NOT NULL
    )
    """

    for attempt in range(30):
        try:
            connection = get_db_connection()
            cursor = connection.cursor()

            cursor.execute(create_table_query)
            connection.commit()

            cursor.close()
            connection.close()

            print("Database initialized successfully.")
            return

        except mysql.connector.Error as error:
            print(f"Database not ready (attempt {attempt + 1}/30): {error}")
            time.sleep(2)

    raise RuntimeError("Could not connect to MySQL after multiple attempts.")


@app.get("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.get("/api/items")
def get_items():
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)

    cursor.execute(
        "SELECT id, name, price, stock FROM products ORDER BY id"
    )

    items = cursor.fetchall()

    cursor.close()
    connection.close()

    for item in items:
        item["price"] = float(item["price"])

    return jsonify(items), 200


@app.post("/api/items")
def add_item():
    data = request.get_json()

    if not data:
        return jsonify({"error": "JSON body is required"}), 400

    name = data.get("name")
    price = data.get("price")
    stock = data.get("stock")

    if name is None or price is None or stock is None:
        return jsonify({
            "error": "name, price and stock are required"
        }), 400

    try:
        price = float(price)
        stock = int(stock)
    except (ValueError, TypeError):
        return jsonify({
            "error": "price must be a number and stock must be an integer"
        }), 400

    if price < 0 or stock < 0:
        return jsonify({
            "error": "price and stock cannot be negative"
        }), 400

    connection = get_db_connection()
    cursor = connection.cursor()

    cursor.execute(
        """
        INSERT INTO products (name, price, stock)
        VALUES (%s, %s, %s)
        """,
        (name, price, stock)
    )

    connection.commit()
    product_id = cursor.lastrowid

    cursor.close()
    connection.close()

    return jsonify({
        "id": product_id,
        "name": name,
        "price": price,
        "stock": stock
    }), 201


if __name__ == "__main__":
    initialize_database()

    app.run(
        host="0.0.0.0",
        port=5000
    )
