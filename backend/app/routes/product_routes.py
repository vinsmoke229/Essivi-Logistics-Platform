from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Product
from flask_jwt_extended import jwt_required, get_jwt

product_bp = Blueprint('products', __name__, url_prefix='/api/products')

# Lire les prix
@product_bp.route('/', methods=['GET'])
def get_products():
    products = Product.query.all()
    # Si la table est vide, on l'initialise (Sécurité démo)
    if not products:
        p1 = Product(name="Vitale", price=500)
        p2 = Product(name="Voltic", price=600)
        db.session.add_all([p1, p2])
        db.session.commit()
        products = [p1, p2]

    return jsonify([
        {"id": p.id, "name": p.name, "price": p.price} for p in products
    ]), 200

# Modifier un prix (Admin seulement)
@product_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_product(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Non autorisé"}), 403

    product = Product.query.get_or_404(id)
    data = request.get_json()
    
    if 'price' in data:
        product.price = float(data['price'])
        db.session.commit()
        
    return jsonify({"msg": "Prix mis à jour"}), 200