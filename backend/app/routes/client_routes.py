from flask import Blueprint, request, jsonify, send_file, current_app
from sqlalchemy.exc import IntegrityError
from app import db
from app.models.sql_models import Client
from flask_jwt_extended import jwt_required, get_jwt
from app.utils import log_action
from werkzeug.security import generate_password_hash
from werkzeug.utils import secure_filename
import os
from datetime import datetime

client_bp = Blueprint('clients', __name__, url_prefix='/api/clients')

def format_url(url):
    if not url: return None
    if url.startswith('http'): return url
    path = url[1:] if url.startswith('/') else url
    return f"{request.host_url}{path}"

# Helper pour obtenir le chemin absolu du dossier uploads
def get_upload_path():
    # On remonte d'un niveau depuis 'app' pour trouver 'uploads' à la racine du projet
    # current_app.root_path est généralement .../backend/app
    # donc .../backend/app/../uploads/clients pointera vers .../backend/uploads/clients
    base_path = os.path.dirname(os.path.abspath(current_app.root_path))
    return os.path.join(base_path, 'uploads', 'clients')

def ensure_upload_dir():
    path = get_upload_path()
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path

# --- 1. CRÉER UN CLIENT ---
@client_bp.route('/', methods=['POST'])
def create_client():
    from flask_jwt_extended import verify_jwt_in_request
    
    data = request.get_json()
    
    if not data.get('name') or not data.get('phone'):
        return jsonify({"msg": "Nom et téléphone obligatoires"}), 400

    if Client.query.filter_by(phone=data['phone'], is_active=True).first():
        return jsonify({"msg": "Ce numéro de téléphone est déjà utilisé par un client actif"}), 409

    # Gestion du PIN (Par défaut '0000' si non fourni)
    pin_to_hash = data.get('pin', '0000')
    pin_hash = generate_password_hash(pin_to_hash)

    new_client = Client(
        name=data['name'],
        responsible_name=data.get('responsible_name', ''),
        phone=data['phone'],
        email=data.get('email'),
        address=data.get('address', ''),
        gps_lat=data.get('gps_lat'),
        gps_lng=data.get('gps_lng'),
        photo_url=data.get('photo_url'),
        pin_hash=pin_hash,
        is_active=True
    )

    try:
        db.session.add(new_client)
        db.session.commit()
        
        from flask_jwt_extended import verify_jwt_in_request
        user_id = None
        agent_id = None
        try:
            verify_jwt_in_request(optional=True)
            claims = get_jwt()
            if claims:
                if claims.get('type') == 'admin': user_id = claims.get('sub')
                if claims.get('type') == 'agent': agent_id = claims.get('sub')
        except:
            pass

        log_action(
            user_id=user_id,
            agent_id=agent_id,
            action="CREATE_CLIENT",
            entity_type="client",
            entity_id=new_client.id,
            details={"name": new_client.name, "phone": new_client.phone}
        )
        
        return jsonify({"msg": f"Client ajouté avec succès. Code PIN par défaut: {pin_to_hash}", "id": new_client.id}), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Cet email ou ce téléphone est déjà utilisé"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# --- 2. LISTER LES CLIENTS (Uniquement actifs) ---
@client_bp.route('/', methods=['GET'])
@jwt_required()
def get_clients():
    clients = Client.query.filter_by(is_active=True).all()
    result = []
    for client in clients:
        result.append({
            "id": str(client.id),
            "name": client.name,
            "responsible_name": client.responsible_name,
            "phone": client.phone,
            "email": client.email,
            "address": client.address,
            "photo_url": format_url(client.photo_url),
            "gps_lat": client.gps_lat,
            "gps_lng": client.gps_lng,
            "is_active": client.is_active
        })
    return jsonify(result), 200

# --- 3. LIRE UN CLIENT ---
@client_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_client(id):
    client = Client.query.get_or_404(id)
    if not client.is_active:
        return jsonify({"msg": "Ce client a été supprimé"}), 410

    return jsonify({
        "id": str(client.id),
        "name": client.name,
        "responsible_name": client.responsible_name,
        "phone": client.phone,
        "email": client.email,
        "photo_url": format_url(client.photo_url),
        "address": client.address,
        "is_active": client.is_active,
        "gps": {"lat": client.gps_lat, "lng": client.gps_lng},
        "stats": {
            "total_deliveries": len(client.deliveries)
        }
    }), 200

# --- 4. MISE À JOUR CLIENT ---
@client_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_client(id):
    client = Client.query.get_or_404(id)
    data = request.get_json()

    if 'name' in data: client.name = data['name']
    if 'responsible_name' in data: client.responsible_name = data['responsible_name']
    if 'phone' in data: client.phone = data['phone']
    if 'email' in data: client.email = data['email']
    if 'address' in data: client.address = data['address']
    if 'gps_lat' in data: client.gps_lat = data['gps_lat']
    if 'gps_lng' in data: client.gps_lng = data['gps_lng']
    if 'photo_url' in data: client.photo_url = data['photo_url']
    if 'pin' in data: client.pin_hash = generate_password_hash(data['pin'])
    if 'is_active' in data: client.is_active = data['is_active']

    try:
        db.session.commit()
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
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Cet email ou ce téléphone est déjà utilisé par un autre compte"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur update : {str(e)}"}), 500

# --- 5. SUPPRIMER UN CLIENT (Soft Delete) ---
@client_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_client(id):
    claims = get_jwt()
    if claims.get('role') != 'super_admin' and claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403

    client = Client.query.get_or_404(id)
    
    try:
        # Action : Soft Delete au lieu de Hard Delete pour éviter les erreurs de contrainte
        client.is_active = False
        db.session.commit()
        
        log_action(
            user_id=claims.get('sub'),
            action="DELETE_CLIENT_SOFT",
            entity_type="client",
            entity_id=client.id,
            details={"name": client.name, "note": "Soft delete applied"}
        )
        return jsonify({"msg": "Client désactivé avec succès"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# --- 6. UPLOAD PHOTO POINT DE VENTE ---
@client_bp.route('/upload-photo', methods=['POST'])
@jwt_required()
def upload_client_photo():
    try:
        if 'photo' not in request.files:
            return jsonify({"msg": "Aucun fichier photo fourni"}), 400
            
        file = request.files['photo']
        if file.filename == '':
            return jsonify({"msg": "Nom de fichier invalide"}), 400
            
        upload_dir = ensure_upload_dir()
        filename = secure_filename(f"client_{datetime.now().strftime('%Y%m%d%H%M%S')}.png")
        filepath = os.path.join(upload_dir, filename)
        file.save(filepath)
        
        photo_url = f"/api/clients/photo-file/{filename}"
        return jsonify({"msg": "Photo uploadée", "url": format_url(photo_url)}), 200
    except Exception as e:
        return jsonify({"msg": f"Erreur upload: {str(e)}"}), 500

@client_bp.route('/photo-file/<filename>', methods=['GET'])
def get_client_photo(filename):
    upload_dir = get_upload_path()
    filepath = os.path.join(upload_dir, filename)
    
    # Debug log (optionnel, à commenter en prod)
    # print(f"Tentative d'accès à la photo: {filepath}")
    
    if os.path.exists(filepath):
        return send_file(filepath)
    
    return jsonify({"msg": "Photo non trouvée"}), 404