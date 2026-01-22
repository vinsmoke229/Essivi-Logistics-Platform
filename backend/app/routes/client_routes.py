from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Client
from flask_jwt_extended import jwt_required, get_jwt
from app.utils import log_action

client_bp = Blueprint('clients', __name__, url_prefix='/api/clients')

# --- 1. CRÉER UN CLIENT ---
# Autorisé aux Admins ET aux Agents (selon cahier des charges 3.1.2 NB)
@client_bp.route('/', methods=['POST'])
@jwt_required()
def create_client():
    data = request.get_json()
    
    # Validation simple
    if not data.get('name') or not data.get('phone'):
        return jsonify({"msg": "Nom et téléphone obligatoires"}), 400

    # Vérification doublon
    if Client.query.filter_by(phone=data['phone']).first():
        return jsonify({"msg": "Ce numéro de téléphone est déjà utilisé par un client"}), 409

    new_client = Client(
        name=data['name'],
        responsible_name=data.get('responsible_name', ''),
        phone=data['phone'],
        address=data.get('address', ''),
        gps_lat=data.get('gps_lat'), # Latitude (ex: 6.12345)
        gps_lng=data.get('gps_lng')  # Longitude (ex: 1.23456)
    )

    try:
        db.session.add(new_client)
        db.session.commit()
        
        # LOG D'AUDIT
        claims = get_jwt()
        log_action(
            user_id=claims.get('sub') if claims.get('type') == 'admin' else None,
            agent_id=claims.get('sub') if claims.get('type') == 'agent' else None,
            action="CREATE_CLIENT",
            entity_type="client",
            entity_id=new_client.id,
            details={"name": new_client.name, "phone": new_client.phone}
        )
        
        return jsonify({"msg": "Client ajouté avec succès", "id": new_client.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# --- 2. LISTER LES CLIENTS ---
@client_bp.route('/', methods=['GET'])
@jwt_required()
def get_clients():
    clients = Client.query.all()
    result = []
    for client in clients:
        result.append({
            "id": client.id,
            "name": client.name,
            "responsible_name": client.responsible_name,
            "phone": client.phone,
            "address": client.address,
            "gps_lat": client.gps_lat,
            "gps_lng": client.gps_lng,
            "is_active": True # Statut par défaut
        })
    return jsonify(result), 200

# --- LIRE UN CLIENT PAR ID ---
@client_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_client(id):
    client = Client.query.get_or_404(id)
    return jsonify({
        "id": client.id,
        "name": client.name,
        "responsible_name": client.responsible_name,
        "phone": client.phone,
        "address": client.address,
        "is_active": True, # Par défaut
        "gps": {"lat": client.gps_lat, "lng": client.gps_lng},
        "stats": {
            "total_deliveries": len(client.deliveries)
        }
    }), 200

# --- 3. MISE À JOUR CLIENT ---
@client_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_client(id):
    client = Client.query.get_or_404(id)
    data = request.get_json()

    if 'name' in data: client.name = data['name']
    if 'responsible_name' in data: client.responsible_name = data['responsible_name']
    if 'phone' in data: client.phone = data['phone']
    if 'address' in data: client.address = data['address']
    if 'gps_lat' in data: client.gps_lat = data['gps_lat']
    if 'gps_lng' in data: client.gps_lng = data['gps_lng']

    try:
        db.session.commit()
        
        # LOG D'AUDIT
        claims = get_jwt()
        log_action(
            user_id=claims.get('sub') if claims.get('type') == 'admin' else None,
            agent_id=claims.get('sub') if claims.get('type') == 'agent' else None,
            action="UPDATE_CLIENT",
            entity_type="client",
            entity_id=client.id,
            details=data
        )
        
        return jsonify({"msg": "Client mis à jour"}), 200
    except Exception as e:
        return jsonify({"msg": "Erreur update"}), 500

# --- 4. SUPPRIMER UN CLIENT ---
@client_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_client(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403

    client = Client.query.get_or_404(id)
    
    try:
        client_id = client.id
        client_name = client.name
        db.session.delete(client)
        db.session.commit()
        
        # LOG D'AUDIT
        log_action(
            user_id=claims.get('sub'),
            action="DELETE_CLIENT",
            entity_type="client",
            entity_id=client_id,
            details={"name": client_name}
        )
        
        return jsonify({"msg": "Client supprimé"}), 200
    except Exception as e:
        return jsonify({"msg": "Erreur suppression"}), 500