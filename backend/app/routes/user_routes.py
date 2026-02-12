from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import User
from werkzeug.security import generate_password_hash
from flask_jwt_extended import jwt_required, get_jwt
from app.utils import log_action
from app.utils.helpers import roles_required

user_bp = Blueprint('users', __name__, url_prefix='/api/users')


@user_bp.route('/', methods=['GET'])
@jwt_required()
@roles_required(['super_admin', 'manager', 'supervisor'])
def get_users():
    users = User.query.all()
    result = []
    
    for u in users:
        result.append({
            "id": u.id, 
            "username": u.username, 
            "full_name": u.full_name or u.username,
            "email": u.email, 
            "role": u.role,
            "is_active": u.is_active,
            "last_login": u.last_login.isoformat() if u.last_login else None,
            "created_at": u.created_at.strftime("%d/%m/%Y %H:%M")
        })
        
    return jsonify(result), 200


@user_bp.route('/', methods=['POST'])
@jwt_required()
@roles_required(['super_admin'])
def create_user():
    claims = get_jwt()
    data = request.get_json()
    
    
    if not data.get('username') or not data.get('email') or not data.get('password'):
        return jsonify({"msg": "Champs obligatoires manquants"}), 400
        
    
    if User.query.filter((User.email == data['email']) | (User.username == data['username'])).first():
        return jsonify({"msg": "Email ou Username déjà utilisé"}), 409
        
    try:
        new_user = User(
            username=data['username'],
            full_name=data.get('full_name'),
            email=data['email'],
            password_hash=generate_password_hash(data['password']),
            role=data.get('role', 'manager'),
            is_active=data.get('is_active', True)
        )
        
        db.session.add(new_user)
        db.session.commit()
        
        
        log_action(
            user_id=claims.get('sub'),
            action="CREATE_USER",
            entity_type="user",
            entity_id=new_user.id,
            details={"username": new_user.username, "role": new_user.role}
        )
        
        return jsonify({"msg": "Utilisateur créé avec succès", "id": str(new_user.id)}), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur serveur: {str(e)}"}), 500


@user_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
@roles_required(['super_admin'])
def update_user(id):
    claims = get_jwt()
    user = User.query.get_or_404(id)
    data = request.get_json()
    
    if 'username' in data: user.username = data['username']
    if 'full_name' in data: user.full_name = data['full_name']
    if 'email' in data: user.email = data['email']
    if 'role' in data: user.role = data['role']
    if 'is_active' in data: user.is_active = data['is_active']
    
    if 'password' in data and data['password']:
        user.password_hash = generate_password_hash(data['password'])
        
    try:
        db.session.commit()
        
        log_action(
            user_id=claims.get('sub'),
            action="UPDATE_USER",
            entity_type="user",
            entity_id=user.id,
            details=data
        )
        
        return jsonify({"msg": "Utilisateur mis à jour"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Erreur mise à jour"}), 500


@user_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
@roles_required(['super_admin'])
def delete_user(id):
    claims = get_jwt()
        
    
    if str(claims.get('sub')) == str(id):
        return jsonify({"msg": "Vous ne pouvez pas supprimer votre propre compte"}), 400
        
    user = User.query.get_or_404(id)
    
    try:
        username = user.username
        db.session.delete(user)
        db.session.commit()
        
        log_action(
            user_id=claims.get('sub'),
            action="DELETE_USER",
            entity_type="user",
            entity_id=id,
            details={"username": username}
        )
        
        return jsonify({"msg": "Utilisateur supprimé"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Erreur suppression"}), 500


@user_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    claims = get_jwt()
    user_id = claims.get('sub')
    user = User.query.get(user_id)
    
    if not user:
        return jsonify({"msg": "Utilisateur non trouvé"}), 404
        
    data = request.get_json()
    if 'full_name' in data: user.full_name = data['full_name']
    if 'password' in data and data['password']:
        user.password_hash = generate_password_hash(data['password'])
        
    try:
        db.session.commit()
        return jsonify({"msg": "Profil mis à jour"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Erreur"}), 500
