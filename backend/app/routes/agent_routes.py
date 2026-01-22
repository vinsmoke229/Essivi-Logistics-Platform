from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Agent
from flask_jwt_extended import jwt_required, get_jwt, get_jwt_identity
from werkzeug.security import generate_password_hash
from app.utils import log_action

agent_bp = Blueprint('agents', __name__, url_prefix='/api/agents')

# --- AJOUTER UN AGENT ---
@agent_bp.route('/', methods=['POST'])
@jwt_required()
def create_agent():
    # CORRECTION : On récupère les "claims" (infos supplémentaires)
    claims = get_jwt()
    
    # Vérification stricte du cahier des charges : Seul l'admin gère les agents
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès réservé aux administrateurs"}), 403

    data = request.get_json()
    
    required_fields = ['matricule', 'full_name', 'phone', 'password']
    for field in required_fields:
        if field not in data:
            return jsonify({"msg": f"Le champ {field} est obligatoire"}), 400

    if Agent.query.filter((Agent.matricule == data['matricule']) | (Agent.phone == data['phone'])).first():
        return jsonify({"msg": "Un agent avec ce matricule ou ce téléphone existe déjà"}), 409

    new_agent = Agent(
        matricule=data['matricule'],
        full_name=data['full_name'],
        phone=data['phone'],
        tricycle_plate=data.get('tricycle_plate', ''),
        password_hash=generate_password_hash(data['password'])
    )

    try:
        db.session.add(new_agent)
        db.session.commit()
        
        # LOG D'AUDIT
        log_action(
            user_id=claims.get('sub'), # ID de l'admin car jwt_required
            action="CREATE_AGENT",
            entity_type="agent",
            entity_id=new_agent.id,
            details={"matricule": new_agent.matricule, "full_name": new_agent.full_name}
        )
        
        return jsonify({"msg": "Agent créé avec succès", "id": new_agent.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# --- LISTER LES AGENTS ---
@agent_bp.route('/', methods=['GET'])
@jwt_required()
def get_agents():
    # Optionnel : vérifier si c'est un admin, mais un agent pourrait vouloir voir ses collègues ?
    # Pour l'instant on laisse ouvert aux connectés, ou on restreint aux admins :
    claims = get_jwt()
    if claims.get('type') != 'admin':
         return jsonify({"msg": "Accès réservé aux administrateurs"}), 403

    agents = Agent.query.all()
    result = []
    for agent in agents:
        result.append({
            "id": agent.id,
            "matricule": agent.matricule,
            "full_name": agent.full_name,
            "phone": agent.phone,
            "tricycle_plate": agent.tricycle_plate,
            "is_active": agent.is_active,
            "last_lat": agent.last_lat,
            "last_lng": agent.last_lng,
            "last_seen": agent.last_seen.strftime("%Y-%m-%dT%H:%M:%SZ") if agent.last_seen else None
        })
    return jsonify(result), 200

# --- LIRE UN AGENT PAR SES INFOS --- 
@agent_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_agent(id):
    agent = Agent.query.get_or_404(id)
    
    # Calcul de stats simples pour le profil
    total_deliveries = len(agent.deliveries)
    total_revenue = sum(d.total_amount for d in agent.deliveries)

    return jsonify({
        "id": agent.id,
        "matricule": agent.matricule,
        "full_name": agent.full_name,
        "phone": agent.phone,
        "tricycle_plate": agent.tricycle_plate,
        "is_active": agent.is_active,
        "last_lat": agent.last_lat,
        "last_lng": agent.last_lng,
        "last_seen": agent.last_seen.strftime("%Y-%m-%dT%H:%M:%SZ") if agent.last_seen else None,
        "stats": {
            "total_deliveries": total_deliveries,
            "total_revenue": total_revenue
        }
    }), 200

# --- MODIFIER UN AGENT ---
@agent_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_agent(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403

    agent = Agent.query.get_or_404(id)
    data = request.get_json()

    if 'full_name' in data: agent.full_name = data['full_name']
    if 'phone' in data: agent.phone = data['phone']
    if 'tricycle_plate' in data: agent.tricycle_plate = data['tricycle_plate']
    if 'is_active' in data: agent.is_active = data['is_active']
    
    if 'password' in data and data['password']:
        agent.password_hash = generate_password_hash(data['password'])

    try:
        db.session.commit()
        
        # LOG D'AUDIT
        log_action(
            user_id=claims.get('sub'),
            action="UPDATE_AGENT",
            entity_type="agent",
            entity_id=agent.id,
            details=data # On logue ce qui a été envoyé
        )
        
        return jsonify({"msg": "Agent mis à jour avec succès"}), 200
    except Exception as e:
        return jsonify({"msg": "Erreur lors de la mise à jour"}), 500

# --- SUPPRIMER UN AGENT ---
@agent_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_agent(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403

    agent = Agent.query.get_or_404(id)
    
    try:
        agent_id = agent.id
        db.session.delete(agent)
        db.session.commit()
        
        # LOG D'AUDIT
        log_action(
            user_id=claims.get('sub'),
            action="DELETE_AGENT",
            entity_type="agent",
            entity_id=agent_id,
            details={"name": agent.full_name, "matricule": agent.matricule}
        )
        
        return jsonify({"msg": "Agent supprimé avec succès"}), 200
    except Exception as e:
        return jsonify({"msg": "Erreur suppression"}), 500

# --- METTRE À JOUR LA POSITION GPS (Suivi Temps Réel) ---
@agent_bp.route('/location', methods=['POST'])
@jwt_required()
def update_location():
    claims = get_jwt()
    if claims.get('type') != 'agent':
        return jsonify({"msg": "Réservé aux agents"}), 403

    agent_id = claims['sub']
    data = request.get_json()
    
    lat = data.get('lat')
    lng = data.get('lng')

    if not lat or not lng:
        return jsonify({"msg": "Coordonnées manquantes"}), 400

    agent = Agent.query.get(agent_id)
    if not agent:
        return jsonify({"msg": "Agent introuvable"}), 404

    from datetime import datetime
    agent.last_lat = lat
    agent.last_lng = lng
    agent.last_seen = datetime.utcnow()

    try:
        db.session.commit()
        return jsonify({"msg": "Position mise à jour"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Erreur lors de la mise à jour"}), 500