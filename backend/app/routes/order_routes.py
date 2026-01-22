from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Order, Client, Agent
from flask_jwt_extended import jwt_required, get_jwt

order_bp = Blueprint('orders', __name__, url_prefix='/api/orders')

# 1. CRÉER UNE COMMANDE (Client)
@order_bp.route('/', methods=['POST'])
@jwt_required()
def create_order():
    claims = get_jwt()
    if claims.get('type') != 'client' and claims.get('type') != 'admin':
        return jsonify({"msg": "Non autorisé"}), 403

    data = request.get_json()
    # Si c'est l'admin qui crée pour un client, il passe le client_id dans le body
    client_id = data.get('client_id') if claims.get('type') == 'admin' else int(claims['sub'])

    new_order = Order(
        client_id=client_id,
        quantity_vitale=data.get('quantity_vitale', 0),
        quantity_voltic=data.get('quantity_voltic', 0),
        preferred_delivery_time=data.get('preferred_time'),
        instructions=data.get('instructions'),
        status='pending'
    )

    try:
        db.session.add(new_order)
        db.session.commit()
        return jsonify({"msg": "Commande enregistrée", "id": new_order.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# 2. LISTER LES COMMANDES (Connecté au Frontend)
@order_bp.route('/', methods=['GET'])
@jwt_required()
def get_orders():
    claims = get_jwt()
    user_type = claims.get('type')

    if user_type == 'admin':
        orders = Order.query.order_by(Order.created_at.desc()).all()
    elif user_type == 'client':
        orders = Order.query.filter_by(client_id=int(claims['sub'])).order_by(Order.created_at.desc()).all()
    else: # Agent
        orders = Order.query.filter_by(agent_id=int(claims['sub'])).order_by(Order.created_at.desc()).all()

    result = []
    for o in orders:
        result.append({
            "id": o.id,
            "client_name": o.client.name,
            "agent_id": o.agent_id, # Crucial pour le Frontend
            "agent_name": o.agent.full_name if o.agent else None,
            "quantity_vitale": o.quantity_vitale,
            "quantity_voltic": o.quantity_voltic,
            "status": o.status,
            "created_at": o.created_at.strftime("%d/%m/%Y %H:%M")
        })
    return jsonify(result), 200

# 3. ASSIGNER UNE COMMANDE (Route d'attribution)
@order_bp.route('/<int:id>/assign', methods=['PUT'])
@jwt_required()
def assign_order(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Réservé aux administrateurs"}), 403

    order = Order.query.get_or_404(id)
    data = request.get_json()
    agent_id = data.get('agent_id')

    if not agent_id:
        return jsonify({"msg": "Sélectionnez un agent"}), 400

    order.agent_id = int(agent_id)
    order.status = 'accepted' # La commande passe en mode 'validé'
    
    try:
        db.session.commit()
        return jsonify({"msg": "Agent assigné avec succès"}), 200
    except:
        db.session.rollback()
        return jsonify({"msg": "Erreur serveur"}), 500