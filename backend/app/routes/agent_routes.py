from flask import Blueprint, request, jsonify, send_file, current_app
from app import db
from app.models.sql_models import Agent, Tour
from flask_jwt_extended import jwt_required, get_jwt, get_jwt_identity
from werkzeug.security import generate_password_hash
from werkzeug.utils import secure_filename
from app.utils import log_action
import os
from datetime import datetime

agent_bp = Blueprint('agents', __name__, url_prefix='/api/agents')

def format_url(url):
    if not url: return None
    if url.startswith('http'): return url
    path = url[1:] if url.startswith('/') else url
    return f"{request.host_url}{path}"

# Helper pour obtenir le chemin absolu du dossier uploads agents
def get_agent_upload_path():
    return os.path.abspath(os.path.join(current_app.root_path, '..', 'uploads', 'agents'))

def ensure_agent_upload_dir():
    path = get_agent_upload_path()
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path

# --- AJOUTER UN AGENT ---
@agent_bp.route('/', methods=['POST'])
@jwt_required()
def create_agent():
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès réservé aux administrateurs"}), 403

    data = request.get_json()
    
    required_fields = ['matricule', 'full_name', 'phone', 'password']
    for field in required_fields:
        if field not in data:
            return jsonify({"msg": f"Le champ {field} est obligatoire"}), 400

    if Agent.query.filter((Agent.matricule == data['matricule']) | (Agent.phone == data['phone'])).first():
        return jsonify({"msg": "Un agent avec ce matricule ou ce téléphone existe déjà"}), 409

    # Parsing des dates
    birth_date = None
    hire_date = None
    if data.get('birth_date'):
        birth_date = datetime.strptime(data['birth_date'], '%Y-%m-%d').date()
    if data.get('hire_date'):
        hire_date = datetime.strptime(data['hire_date'], '%Y-%m-%d').date()

    new_agent = Agent(
        matricule=data['matricule'],
        full_name=data['full_name'],
        phone=data['phone'],
        email=data.get('email'),
        address=data.get('address'),
        birth_date=birth_date,
        hire_date=hire_date,
        tricycle_plate=data.get('tricycle_plate', ''),
        photo_url=data.get('photo_url'),
        password_hash=generate_password_hash(data['password'])
    )

    try:
        db.session.add(new_agent)
        db.session.commit()
        
        log_action(
            user_id=claims.get('sub'),
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
            "email": agent.email,
            "address": agent.address,
            "birth_date": agent.birth_date.isoformat() if agent.birth_date else None,
            "hire_date": agent.hire_date.isoformat() if agent.hire_date else None,
            "photo_url": format_url(agent.photo_url),
            "tricycle_plate": agent.tricycle_plate,
            "is_active": agent.is_active,
            "average_rating": agent.average_rating,
            "punctuality_rate": agent.punctuality_rate,
            "is_on_duty": agent.is_on_duty
        })
    return jsonify(result), 200

# --- LIRE UN AGENT PAR ID ---
@agent_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_agent(id):
    try:
        agent = Agent.query.get_or_404(id)
        
        # Calcul sécurisé des stats
        deliveries = agent.deliveries if agent.deliveries else []
        total_deliveries = len(deliveries)
        total_revenue = sum(getattr(d, 'total_amount', 0) for d in deliveries)

        # Récupérer l'historique des tournées de manière sécurisée
        tours_history = []
        tours = agent.tours if agent.tours else []
        for tour in tours:
            tours_history.append({
                "id": tour.id,
                "start_time": tour.start_time.strftime("%Y-%m-%dT%H:%M:%SZ") if tour.start_time else None,
                "end_time": tour.end_time.strftime("%Y-%m-%dT%H:%M:%SZ") if tour.end_time else None,
                "total_deliveries": getattr(tour, 'total_deliveries', 0),
                "total_cash_collected": getattr(tour, 'total_cash_collected', 0.0),
                "status": "terminée" if getattr(tour, 'end_time', None) else "en cours"
            })

        # Sérialisation robuste des livraisons
        deliveries_list = []
        for d in deliveries:
            deliveries_list.append({
                "id": d.id,
                "date": d.date.strftime("%Y-%m-%dT%H:%M:%SZ") if d.date else None,
                "client_name": d.client.name if (hasattr(d, 'client') and d.client) else "Inconnu",
                "total_amount": getattr(d, 'total_amount', 0),
                "gps_lat": getattr(d, 'gps_lat', None),
                "gps_lng": getattr(d, 'gps_lng', None)
            })

        return jsonify({
            "id": agent.id,
            "matricule": agent.matricule,
            "full_name": agent.full_name,
            "phone": agent.phone,
            "email": agent.email,
            "address": agent.address,
            "birth_date": agent.birth_date.isoformat() if agent.birth_date else None,
            "hire_date": agent.hire_date.isoformat() if agent.hire_date else None,
            "photo_url": format_url(agent.photo_url),
            "tricycle_plate": agent.tricycle_plate,
            "is_active": agent.is_active,
            "average_rating": getattr(agent, 'average_rating', 5.0),
            "punctuality_rate": getattr(agent, 'punctuality_rate', 100.0),
            "is_on_duty": getattr(agent, 'is_on_duty', False),
            "stats": {
                "total_deliveries": total_deliveries,
                "total_revenue": total_revenue
            },
            "tours": tours_history,
            "deliveries": deliveries_list
        }), 200
    except Exception as e:
        import traceback
        print(f"❌ Erreur critique GET /agents/{id}: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"msg": "Erreur interne lors du chargement de l'agent", "error": str(e)}), 500

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
    if 'email' in data: agent.email = data['email']
    if 'address' in data: agent.address = data['address']
    if 'tricycle_plate' in data: agent.tricycle_plate = data['tricycle_plate']
    if 'is_active' in data: agent.is_active = data['is_active']
    if 'photo_url' in data: agent.photo_url = data['photo_url']
    
    if data.get('birth_date'):
        agent.birth_date = datetime.strptime(data['birth_date'], '%Y-%m-%d').date()
    if data.get('hire_date'):
        agent.hire_date = datetime.strptime(data['hire_date'], '%Y-%m-%d').date()

    if 'password' in data and data['password']:
        agent.password_hash = generate_password_hash(data['password'])

    try:
        db.session.commit()
        log_action(
            user_id=claims.get('sub'),
            action="UPDATE_AGENT",
            entity_type="agent",
            entity_id=agent.id,
            details=data
        )
        return jsonify({"msg": "Agent mis à jour avec succès"}), 200
    except Exception as e:
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# --- UPLOAD PHOTO AGENT ---
@agent_bp.route('/upload-photo', methods=['POST'])
@jwt_required()
def upload_agent_photo():
    try:
        if 'photo' not in request.files:
            return jsonify({"msg": "Aucun fichier photo fourni"}), 400
            
        file = request.files['photo']
        if file.filename == '':
            return jsonify({"msg": "Nom de fichier invalide"}), 400
            
        upload_dir = ensure_agent_upload_dir()
        filename = secure_filename(f"agent_{datetime.now().strftime('%Y%m%d%H%M%S')}.png")
        filepath = os.path.join(upload_dir, filename)
        file.save(filepath)
        
        photo_url = f"/api/agents/photo-file/{filename}"
        return jsonify({"msg": "Photo uploadée", "url": format_url(photo_url)}), 200
    except Exception as e:
        return jsonify({"msg": f"Erreur upload: {str(e)}"}), 500

@agent_bp.route('/photo-file/<filename>', methods=['GET'])
def get_agent_photo(filename):
    filepath = os.path.join(UPLOAD_AGENT_FOLDER, filename)
    if os.path.exists(filepath):
        return send_file(filepath)
    return jsonify({"msg": "Photo non trouvée"}), 404

# --- SUPPRIMER UN AGENT ---
@agent_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_agent(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403

    agent = Agent.query.get_or_404(id)
    
    try:
        if agent.deliveries or agent.orders:
            return jsonify({"msg": "Impossible de supprimer cet agent : il a une activité associée"}), 400
        
        db.session.delete(agent)
        db.session.commit()
        
        log_action(
            user_id=claims.get('sub'),
            action="DELETE_AGENT",
            entity_type="agent",
            entity_id=agent.id,
            details={"name": agent.full_name, "matricule": agent.matricule}
        )
        return jsonify({"msg": "Agent supprimé avec succès"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# --- POSITION GPS ---
@agent_bp.route('/location', methods=['POST'])
@jwt_required()
def update_location():
    claims = get_jwt()
    if claims.get('type') != 'agent':
        return jsonify({"msg": "Réservé aux agents"}), 403

    agent_id = int(str(claims['sub']))
    data = request.get_json()
    
    lat = data.get('lat')
    lng = data.get('lng')

    if not lat or not lng:
        return jsonify({"msg": "Coordonnées manquantes"}), 400

    agent = Agent.query.get(agent_id)
    if not agent:
        return jsonify({"msg": "Agent introuvable"}), 404

    agent.last_lat = lat
    agent.last_lng = lng
    agent.last_seen = datetime.utcnow()

    try:
        db.session.commit()
        return jsonify({"msg": "Position mise à jour"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Erreur lors de la mise à jour"}), 500