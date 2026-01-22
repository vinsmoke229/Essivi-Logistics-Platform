from app.services.audit_service import log_activity
from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Delivery, Agent, Client
from flask_jwt_extended import jwt_required, get_jwt
from app.utils import log_action
from datetime import datetime

delivery_bp = Blueprint('deliveries', __name__, url_prefix='/api/deliveries')

# --- 1. ENREGISTRER UNE LIVRAISON (Mobile Agent) ---
@delivery_bp.route('/', methods=['POST'])
@jwt_required()
def create_delivery():
    claims = get_jwt()
    # Sécurité : On s'assure que l'ID est un entier
    try:
        user_id = int(claims['sub'])
    except:
        user_id = claims['sub']
        
    user_type = claims.get('type')
    data = request.get_json()
    
    if not data or not data.get('client_id') or not data.get('total_amount'):
        return jsonify({"msg": "Données incomplètes (Client et Montant requis)"}), 400

    # On vérifie si le client existe
    client = Client.query.get(data['client_id'])
    if not client:
        return jsonify({"msg": "Client introuvable"}), 404

    # Identifiant de l'agent (automatique si mobile, manuel si admin)
    agent_id = user_id if user_type == 'agent' else data.get('agent_id')

    try:
        # Création de l'objet de livraison
        new_delivery = Delivery(
            agent_id=agent_id,
            client_id=data['client_id'],
            quantity_vitale=int(data.get('quantity_vitale', 0)),
            quantity_voltic=int(data.get('quantity_voltic', 0)),
            total_amount=float(data['total_amount']),
            gps_lat_delivery=data.get('gps_lat'), # Récupère 'gps_lat' du mobile
            gps_lng_delivery=data.get('gps_lng'), # Récupère 'gps_lng' du mobile
            photo_url=data.get('photo_url'),
            signature_url=data.get('signature_url'),
            status='completed',
            date=datetime.utcnow()
        )

        # MISE À JOUR POSITION AGENT
        if user_type == 'agent' and data.get('gps_lat'):
            agent = Agent.query.get(agent_id)
            if agent:
                agent.last_lat = data.get('gps_lat')
                agent.last_lng = data.get('gps_lng')
                agent.last_seen = datetime.utcnow()

        db.session.add(new_delivery)
        db.session.commit()

        # Logs de sécurité (MongoDB + SQL)
        log_activity(user_id, user_type, "CREATE_DELIVERY", {"id": new_delivery.id})
        log_action(user_id=user_id if user_type == 'admin' else None, 
                   agent_id=agent_id if user_type == 'agent' else None,
                   action="CREATE_DELIVERY", entity_type="delivery", 
                   entity_id=new_delivery.id, details=f"Montant: {new_delivery.total_amount}")

        return jsonify({
            "msg": "Livraison enregistrée avec succès", 
            "id": new_delivery.id,
            "date": new_delivery.date.strftime("%Y-%m-%d %H:%M:%S")
        }), 201

    except Exception as e:
        db.session.rollback()
        print(f"❌ ERREUR CRITIQUE LIVRAISON : {str(e)}") # S'affiche dans ton terminal noir
        return jsonify({"msg": f"Erreur interne : {str(e)}"}), 500

# --- 2. LISTER LES LIVRAISONS ---
@delivery_bp.route('/', methods=['GET'])
@jwt_required()
def get_deliveries():
    claims = get_jwt()
    try:
        user_id = int(claims['sub'])
    except:
        user_id = claims['sub']
    
    user_type = claims.get('type')

    if user_type == 'admin':
        deliveries = Delivery.query.order_by(Delivery.date.desc()).all()
    else:
        deliveries = Delivery.query.filter_by(agent_id=user_id).order_by(Delivery.date.desc()).all()

    result = []
    for d in deliveries:
        result.append({
            "id": d.id,
            "created_at": d.date.strftime("%d/%m/%Y %H:%M"),
            "agent_name": d.agent.full_name if d.agent else "Inconnu",
            "client_name": d.client.name if d.client else "Inconnu",
            "quantity_vitale": d.quantity_vitale,
            "quantity_voltic": d.quantity_voltic,
            "total_amount": d.total_amount,
            "gps_lat": d.gps_lat_delivery,
            "gps_lng": d.gps_lng_delivery,
            "status": d.status
        })
    return jsonify(result), 200

# --- 3. LIRE UNE LIVRAISON PAR ID ---
@delivery_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_delivery(id):
    d = Delivery.query.get_or_404(id)
    return jsonify({
        "id": d.id,
        "created_at": d.date.strftime("%d/%m/%Y %H:%M"),
        "agent_name": d.agent.full_name if d.agent else "Inconnu",
        "client_name": d.client.name if d.client else "Inconnu",
        "total_amount": d.total_amount,
        "status": d.status,
        "gps_lat": d.gps_lat_delivery,
        "gps_lng": d.gps_lng_delivery
    }), 200