from flask import Flask, request, jsonify
from datetime import datetime
import hashlib
import random
import os

app = Flask(__name__)

# ==========================================
# CONFIGURATION
# ==========================================

API_TOKEN = os.getenv("API_TOKEN", "formation-token-2026")


# ==========================================
# MARKETPLACE MASTER DATA
# ==========================================

SELLERS = [
    {
        "seller_id": "S001",
        "name": "Maison Élégance",
        "country": "FR",
        "joined_date": "2024-01-15"
    },
    {
        "seller_id": "S002",
        "name": "Urban Goods",
        "country": "FR",
        "joined_date": "2024-03-20"
    },
    {
        "seller_id": "S003",
        "name": "Nordic Design",
        "country": "DE",
        "joined_date": "2024-05-10"
    },
    {
        "seller_id": "S004",
        "name": "Atelier Paris",
        "country": "FR",
        "joined_date": "2024-06-18"
    },
    {
        "seller_id": "S005",
        "name": "Luna Store",
        "country": "ES",
        "joined_date": "2024-08-02"
    }
]


PRODUCTS = [
    {
        "product_id": "P001",
        "name": "Classic Sneakers",
        "category": "Fashion",
        "base_price": 79.90
    },
    {
        "product_id": "P002",
        "name": "Leather Bag",
        "category": "Fashion",
        "base_price": 129.90
    },
    {
        "product_id": "P003",
        "name": "Ceramic Vase",
        "category": "Home",
        "base_price": 45.00
    },
    {
        "product_id": "P004",
        "name": "Desk Lamp",
        "category": "Home",
        "base_price": 59.90
    },
    {
        "product_id": "P005",
        "name": "Wireless Headphones",
        "category": "Electronics",
        "base_price": 99.90
    },
    {
        "product_id": "P006",
        "name": "Smart Watch",
        "category": "Electronics",
        "base_price": 149.90
    },
    {
        "product_id": "P007",
        "name": "Coffee Machine",
        "category": "Kitchen",
        "base_price": 119.90
    },
    {
        "product_id": "P008",
        "name": "Cotton T-Shirt",
        "category": "Fashion",
        "base_price": 29.90
    }
]


CUSTOMERS = [
    {
        "customer_id": "C001",
        "email": "customer1@example.com",
        "city": "Paris",
        "signup_date": "2024-01-10"
    },
    {
        "customer_id": "C002",
        "email": "customer2@example.com",
        "city": "Lyon",
        "signup_date": "2024-02-15"
    },
    {
        "customer_id": "C003",
        "email": "customer3@example.com",
        "city": "Bordeaux",
        "signup_date": "2024-03-22"
    },
    {
        "customer_id": "C004",
        "email": "customer4@example.com",
        "city": "Toulouse",
        "signup_date": "2024-04-05"
    },
    {
        "customer_id": "C005",
        "email": "customer5@example.com",
        "city": "Nantes",
        "signup_date": "2024-05-17"
    },
    {
        "customer_id": "C006",
        "email": "customer6@example.com",
        "city": "Paris",
        "signup_date": "2024-06-12"
    },
    {
        "customer_id": "C007",
        "email": "customer7@example.com",
        "city": "Marseille",
        "signup_date": "2024-07-08"
    },
    {
        "customer_id": "C008",
        "email": "customer8@example.com",
        "city": "Lille",
        "signup_date": "2024-08-19"
    },
    {
        "customer_id": "C009",
        "email": "customer9@example.com",
        "city": "Nice",
        "signup_date": "2024-09-01"
    },
    {
        "customer_id": "C010",
        "email": "customer10@example.com",
        "city": "Strasbourg",
        "signup_date": "2024-10-11"
    }
]


# ==========================================
# AUTHENTICATION
# ==========================================

def check_authentication():
    """Check the Bearer token used by protected endpoints."""

    authorization = request.headers.get("Authorization")

    if not authorization:
        return False

    expected = f"Bearer {API_TOKEN}"

    return authorization == expected


def authentication_error():
    return jsonify({
        "error": "Unauthorized",
        "message": "Valid Bearer token required"
    }), 401


# ==========================================
# DETERMINISTIC RANDOM GENERATOR
# ==========================================

def create_seed(date):
    """
    Create a deterministic seed from the requested date.

    The same date always produces the same random data.
    """

    hash_value = hashlib.md5(date.encode()).hexdigest()

    return int(hash_value[:8], 16)


# ==========================================
# HEALTH CHECK
# ==========================================

@app.get("/health")
def health():

    return jsonify({
        "status": "ok",
        "service": "marketplace-api",
        "version": "1.0.0"
    })


# ==========================================
# SELLERS
# ==========================================

@app.get("/sellers")
def get_sellers():

    if not check_authentication():
        return authentication_error()

    return jsonify(SELLERS)


# ==========================================
# PRODUCTS
# ==========================================

@app.get("/products")
def get_products():

    if not check_authentication():
        return authentication_error()

    return jsonify(PRODUCTS)


# ==========================================
# CUSTOMERS
# ==========================================

@app.get("/customers")
def get_customers():

    if not check_authentication():
        return authentication_error()

    return jsonify(CUSTOMERS)


# ==========================================
# ORDERS
# ==========================================

@app.get("/orders")
def get_orders():

    if not check_authentication():
        return authentication_error()

    date = request.args.get(
        "date",
        datetime.today().strftime("%Y-%m-%d")
    )

    # Validate date
    try:
        datetime.strptime(date, "%Y-%m-%d")
    except ValueError:

        return jsonify({
            "error": "Invalid date",
            "message": "Date must use YYYY-MM-DD format"
        }), 400

    # Deterministic random generator
    random_generator = random.Random(create_seed(date))

    orders = []

    # Generate between 15 and 30 orders for each date
    number_of_orders = random_generator.randint(15, 30)

    for i in range(number_of_orders):

        seller = random_generator.choice(SELLERS)
        customer = random_generator.choice(CUSTOMERS)
        product = random_generator.choice(PRODUCTS)

        quantity = random_generator.randint(1, 5)

        # Small price variation around base price
        price_variation = random_generator.uniform(0.90, 1.10)

        unit_price = round(
            product["base_price"] * price_variation,
            2
        )

        total_amount = round(
            unit_price * quantity,
            2
        )

        status = random_generator.choices(
            ["completed", "cancelled", "pending"],
            weights=[85, 5, 10],
            k=1
        )[0]

        orders.append({

            "order_id": f"O-{date.replace('-', '')}-{i + 1:04d}",

            "seller_id": seller["seller_id"],

            "customer_id": customer["customer_id"],

            "product_id": product["product_id"],

            "quantity": quantity,

            "unit_price": unit_price,

            "total_amount": total_amount,

            "status": status,

            "dt": date
        })

    return jsonify(orders)


# ==========================================
# APPLICATION
# ==========================================

if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False
    )