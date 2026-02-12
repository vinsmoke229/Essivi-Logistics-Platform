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


def get_upload_path():
    
    
    
    base_path = os.path.dirname(os.path.abspath(current_app.root_path))
    return os.path.join(base_path, 'uploads', 'clients')

def ensure_upload_dir():
    path = get_upload_path()
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path


@client_bp.route('/', methods=['POST'])
def create_client():
    from flask_jwt_extended import verify_jwt_in_request
    
    data = request.get_json()
    
    if not data.get('name') or not data.get('phone'):
        return jsonify({"msg": "Nom et téléphone obligatoires"}), 400

    if Client.query.filter_by(phone=data['phone'], is_active=True).first():
        return jsonify({"msg": "Ce numéro de téléphone est déjà utilisé par un client actif"}), 409

    
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
        
        from flask_jwt_extended import create_access_token
        access_token = create_access_token(identity=str(new_client.id), additional_claims={"type": "client", "role": "client", "name": new_client.name})
        
        return jsonify({
            "msg": "Client ajouté avec succès", 
            "id": new_client.id,
            "access_token": access_token,
            "role": "client",
            "name": new_client.name,
            "identifier": new_client.phone
        }), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Ce numéro est déjà enregistré"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Erreur de connexion au serveur"}), 500


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


@client_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_client_profile():
    try:
        client_id = int(get_jwt_identity())
        client = Client.query.get_or_404(client_id)
        
        return jsonify({
            "id": client.id,
            "name": client.name,
            "responsible_name": client.responsible_name,
            "phone": client.phone,
            "email": client.email or "N/A",
            "address": client.address or "Indéfinie",
            "photo_url": format_url(client.photo_url),
            "created_at": client.created_at.isoformat() if client.created_at else None,
            "stats": {
                "total_deliveries": len(client.deliveries),
                "total_orders": len(client.orders)
            }
        }), 200
    except Exception as e:
        return jsonify({"msg": "Erreur profil client", "error": str(e)}), 500



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


@client_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_client(id):
    claims = get_jwt()
    if claims.get('role') != 'super_admin' and claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403

    client = Client.query.get_or_404(id)
    
    try:
        
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
    
    if os.path.exists(filepath):
        return send_file(filepath)
    
    return jsonify({"msg": "Photo non trouvée"}), 404


@client_bp.route('/<int:id>/stats', methods=['GET'])
@jwt_required()
def get_client_stats(id):
    from app.models.sql_models import Delivery
    client = Client.query.get_or_404(id)
    
    
    deliveries = Delivery.query.filter_by(client_id=id, status='completed').order_by(Delivery.date.asc()).all()
    count = len(deliveries)
    
    total_spent = sum(d.total_amount for d in deliveries)
    panier_moyen = total_spent / count if count > 0 else 0
    
    
    frequence = 0
    if count >= 2:
        date_first = deliveries[0].date
        date_last = deliveries[-1].date
        delta_days = (date_last - date_first).days
        frequence = delta_days / count 
        
    return jsonify({
        "info": {
            "id": client.id,
            "name": client.name,
            "responsible_name": client.responsible_name,
            "phone": client.phone
        },
        "bi": {
            "panier_moyen": round(panier_moyen, 2),
            "frequence": round(frequence, 1),
            "solde": 0, 
            "total_livraisons": count,
            "total_depense": total_spent
        }
    }), 200