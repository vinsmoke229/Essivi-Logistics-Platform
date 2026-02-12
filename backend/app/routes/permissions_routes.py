from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt
from app import db
from app.models.sql_models import User, Agent, Client
from datetime import datetime

permissions_bp = Blueprint('permissions', __name__, url_prefix='/api/permissions')



class Permission:
    """Définition des permissions granulaires"""
    
    
    MODULE_USERS = 'users'
    MODULE_AGENTS = 'agents'
    MODULE_CLIENTS = 'clients'
    MODULE_ORDERS = 'orders'
    MODULE_DELIVERIES = 'deliveries'
    MODULE_STOCK = 'stock'
    MODULE_SETTINGS = 'settings'
    MODULE_STATS = 'stats'
    MODULE_REPORTS = 'reports'
    MODULE_MAP = 'map'
    MODULE_AUDIT = 'audit'
    
    
    ACTION_CREATE = 'create'
    ACTION_READ = 'read'
    ACTION_UPDATE = 'update'
    ACTION_DELETE = 'delete'
    ACTION_EXPORT = 'export'
    ACTION_MANAGE = 'manage'
    
    
    LEVEL_NONE = 0
    LEVEL_READ = 1
    LEVEL_WRITE = 2
    LEVEL_ADMIN = 3


ROLE_PERMISSIONS = {
    'super_admin': {
        'description': 'Accès complet à tout le système',
        'level': 4,
        'modules': {
            Permission.MODULE_USERS: Permission.LEVEL_ADMIN,
            Permission.MODULE_AGENTS: Permission.LEVEL_ADMIN,
            Permission.MODULE_CLIENTS: Permission.LEVEL_ADMIN,
            Permission.MODULE_ORDERS: Permission.LEVEL_ADMIN,
            Permission.MODULE_DELIVERIES: Permission.LEVEL_ADMIN,
            Permission.MODULE_STOCK: Permission.LEVEL_ADMIN,
            Permission.MODULE_SETTINGS: Permission.LEVEL_ADMIN,
            Permission.MODULE_STATS: Permission.LEVEL_ADMIN,
            Permission.MODULE_REPORTS: Permission.LEVEL_ADMIN,
            Permission.MODULE_MAP: Permission.LEVEL_ADMIN,
            Permission.MODULE_AUDIT: Permission.LEVEL_ADMIN,
        }
    },
    'admin': {
        'description': 'Administration complète sauf utilisateurs système',
        'level': 3,
        'modules': {
            Permission.MODULE_USERS: Permission.LEVEL_READ,
            Permission.MODULE_AGENTS: Permission.LEVEL_ADMIN,
            Permission.MODULE_CLIENTS: Permission.LEVEL_ADMIN,
            Permission.MODULE_ORDERS: Permission.LEVEL_ADMIN,
            Permission.MODULE_DELIVERIES: Permission.LEVEL_ADMIN,
            Permission.MODULE_STOCK: Permission.LEVEL_ADMIN,
            Permission.MODULE_SETTINGS: Permission.LEVEL_ADMIN,
            Permission.MODULE_STATS: Permission.LEVEL_ADMIN,
            Permission.MODULE_REPORTS: Permission.LEVEL_ADMIN,
            Permission.MODULE_MAP: Permission.LEVEL_ADMIN,
            Permission.MODULE_AUDIT: Permission.LEVEL_READ,
        }
    },
    'manager': {
        'description': 'Gestion des opérations quotidiennes',
        'level': 2,
        'modules': {
            Permission.MODULE_USERS: Permission.LEVEL_NONE,
            Permission.MODULE_AGENTS: Permission.LEVEL_WRITE,
            Permission.MODULE_CLIENTS: Permission.LEVEL_WRITE,
            Permission.MODULE_ORDERS: Permission.LEVEL_ADMIN,
            Permission.MODULE_DELIVERIES: Permission.LEVEL_ADMIN,
            Permission.MODULE_STOCK: Permission.LEVEL_WRITE,
            Permission.MODULE_SETTINGS: Permission.LEVEL_READ,
            Permission.MODULE_STATS: Permission.LEVEL_ADMIN,
            Permission.MODULE_REPORTS: Permission.LEVEL_ADMIN,
            Permission.MODULE_MAP: Permission.LEVEL_READ,
            Permission.MODULE_AUDIT: Permission.LEVEL_NONE,
        }
    },
    'supervisor': {
        'description': 'Supervision des agents et livraisons',
        'level': 2,
        'modules': {
            Permission.MODULE_USERS: Permission.LEVEL_NONE,
            Permission.MODULE_AGENTS: Permission.LEVEL_READ,
            Permission.MODULE_CLIENTS: Permission.LEVEL_WRITE,
            Permission.MODULE_ORDERS: Permission.LEVEL_READ,
            Permission.MODULE_DELIVERIES: Permission.LEVEL_ADMIN,
            Permission.MODULE_STOCK: Permission.LEVEL_READ,
            Permission.MODULE_SETTINGS: Permission.LEVEL_NONE,
            Permission.MODULE_STATS: Permission.LEVEL_READ,
            Permission.MODULE_REPORTS: Permission.LEVEL_READ,
            Permission.MODULE_MAP: Permission.LEVEL_READ,
            Permission.MODULE_AUDIT: Permission.LEVEL_NONE,
        }
    },
    'agent': {
        'description': 'Agent de livraison',
        'level': 1,
        'modules': {
            Permission.MODULE_USERS: Permission.LEVEL_NONE,
            Permission.MODULE_AGENTS: Permission.LEVEL_NONE,
            Permission.MODULE_CLIENTS: Permission.LEVEL_READ,
            Permission.MODULE_ORDERS: Permission.LEVEL_READ,
            Permission.MODULE_DELIVERIES: Permission.LEVEL_WRITE,
            Permission.MODULE_STOCK: Permission.LEVEL_READ,
            Permission.MODULE_SETTINGS: Permission.LEVEL_NONE,
            Permission.MODULE_STATS: Permission.LEVEL_READ,
            Permission.MODULE_REPORTS: Permission.LEVEL_READ,
            Permission.MODULE_MAP: Permission.LEVEL_READ,
            Permission.MODULE_AUDIT: Permission.LEVEL_NONE,
        }
    },
    'viewer': {
        'description': 'Lecture seule',
        'level': 1,
        'modules': {
            Permission.MODULE_USERS: Permission.LEVEL_NONE,
            Permission.MODULE_AGENTS: Permission.LEVEL_READ,
            Permission.MODULE_CLIENTS: Permission.LEVEL_READ,
            Permission.MODULE_ORDERS: Permission.LEVEL_READ,
            Permission.MODULE_DELIVERIES: Permission.LEVEL_READ,
            Permission.MODULE_STOCK: Permission.LEVEL_READ,
            Permission.MODULE_SETTINGS: Permission.LEVEL_NONE,
            Permission.MODULE_STATS: Permission.LEVEL_READ,
            Permission.MODULE_REPORTS: Permission.LEVEL_READ,
            Permission.MODULE_MAP: Permission.LEVEL_READ,
            Permission.MODULE_AUDIT: Permission.LEVEL_NONE,
        }
    }
}



def get_user_permissions(user_role: str) -> dict:
    """Récupérer les permissions d'un utilisateur selon son rôle"""
    return ROLE_PERMISSIONS.get(user_role, ROLE_PERMISSIONS['viewer'])

def check_permission(user_role: str, module: str, action: str, level: int = None) -> bool:
    """Vérifier si un utilisateur a la permission pour une action"""
    permissions = get_user_permissions(user_role)
    module_level = permissions['modules'].get(module, Permission.LEVEL_NONE)
    
    if level is not None:
        return module_level >= level
    
    
    action_levels = {
        Permission.ACTION_READ: Permission.LEVEL_READ,
        Permission.ACTION_CREATE: Permission.LEVEL_WRITE,
        Permission.ACTION_UPDATE: Permission.LEVEL_WRITE,
        Permission.ACTION_DELETE: Permission.LEVEL_ADMIN,
        Permission.ACTION_EXPORT: Permission.LEVEL_WRITE,
        Permission.ACTION_MANAGE: Permission.LEVEL_ADMIN,
    }
    
    required_level = action_levels.get(action, Permission.LEVEL_READ)
    return module_level >= required_level

def require_permission(module: str, action: str, level: int = None):
    """Décorateur pour vérifier les permissions"""
    def decorator(f):
        def decorated_function(*args, **kwargs):
            try:
                claims = get_jwt()
                user_role = claims.get('role', 'viewer')
                
                if not check_permission(user_role, module, action, level):
                    return jsonify({
                        "msg": "Accès refusé: permissions insuffisantes",
                        "required": f"{module}:{action}",
                        "user_role": user_role
                    }), 403
                
                return f(*args, **kwargs)
            except Exception as e:
                return jsonify({"msg": f"Erreur de permission: {str(e)}"}), 500
        return decorated_function
    return decorator



@permissions_bp.route('/roles', methods=['GET'])
@jwt_required()
def get_roles():
    """Lister tous les rôles disponibles avec leurs permissions"""
    try:
        claims = get_jwt()
        user_role = claims.get('role', 'viewer')
        
        
        if user_role != 'super_admin':
            return jsonify({"msg": "Accès refusé"}), 403
        
        roles_info = {}
        for role_name, role_data in ROLE_PERMISSIONS.items():
            roles_info[role_name] = {
                'description': role_data['description'],
                'level': role_data['level'],
                'modules': role_data['modules']
            }
        
        return jsonify({
            'roles': roles_info,
            'total_count': len(ROLE_PERMISSIONS)
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@permissions_bp.route('/my-permissions', methods=['GET'])
@jwt_required()
def get_my_permissions():
    """Récupérer les permissions de l'utilisateur connecté"""
    try:
        claims = get_jwt()
        user_role = claims.get('role', 'viewer')
        user_id = claims.get('sub')
        
        permissions = get_user_permissions(user_role)
        
        
        user_info = {}
        if user_role == 'agent':
            agent = Agent.query.filter_by(user_id=user_id).first()
            if agent:
                user_info = {
                    'agent_id': agent.id,
                    'full_name': agent.full_name,
                    'tricycle_plate': agent.tricycle_plate
                }
        elif user_role in ['admin', 'manager', 'supervisor']:
            user = User.query.get(user_id)
            if user:
                user_info = {
                    'email': user.email,
                    'full_name': getattr(user, 'full_name', user.email)
                }
        
        return jsonify({
            'user_role': user_role,
            'permissions': permissions,
            'user_info': user_info
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@permissions_bp.route('/check', methods=['POST'])
@jwt_required()
def check_user_permission():
    """Vérifier une permission spécifique"""
    try:
        data = request.get_json()
        module = data.get('module')
        action = data.get('action')
        level = data.get('level')
        
        claims = get_jwt()
        user_role = claims.get('role', 'viewer')
        
        has_permission = check_permission(user_role, module, action, level)
        
        return jsonify({
            'has_permission': has_permission,
            'user_role': user_role,
            'requested': {
                'module': module,
                'action': action,
                'level': level
            }
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@permissions_bp.route('/module-access', methods=['GET'])
@jwt_required()
def get_module_access():
    """Lister les modules accessibles pour l'utilisateur"""
    try:
        claims = get_jwt()
        user_role = claims.get('role', 'viewer')
        
        permissions = get_user_permissions(user_role)
        accessible_modules = []
        
        for module, level in permissions['modules'].items():
            if level > Permission.LEVEL_NONE:
                accessible_modules.append({
                    'module': module,
                    'level': level,
                    'can_read': level >= Permission.LEVEL_READ,
                    'can_write': level >= Permission.LEVEL_WRITE,
                    'can_admin': level >= Permission.LEVEL_ADMIN
                })
        
        return jsonify({
            'accessible_modules': accessible_modules,
            'user_role': user_role
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@permissions_bp.route('/users/<int:user_id>/role', methods=['PUT'])
@jwt_required()
def update_user_role(user_id):
    """Mettre à jour le rôle d'un utilisateur (admin/super_admin uniquement)"""
    try:
        claims = get_jwt()
        current_role = claims.get('role', 'viewer')
        
        
        if current_role != 'super_admin':
            return jsonify({"msg": "Accès refusé"}), 403
        
        data = request.get_json()
        new_role = data.get('role')
        
        if new_role not in ROLE_PERMISSIONS:
            return jsonify({"msg": "Rôle invalide"}), 400
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({"msg": "Utilisateur non trouvé"}), 404
        
        
        if user.role == 'super_admin' and new_role != 'super_admin':
            super_admin_count = User.query.filter_by(role='super_admin').count()
            if super_admin_count <= 1:
                return jsonify({"msg": "Impossible de modifier le rôle du dernier super_admin"}), 400
        
        old_role = user.role
        user.role = new_role
        user.updated_at = datetime.utcnow()
        db.session.commit()
        
        
        try:
            from app.routes.audit_routes import log_action
            log_action(
                user_id=claims.get('sub'),
                action="ROLE_CHANGE",
                entity_type="user",
                entity_id=user_id,
                details={
                    'old_role': old_role,
                    'new_role': new_role,
                    'target_user': user.email
                }
            )
        except:
            pass
        
        return jsonify({
            "msg": "Rôle mis à jour avec succès",
            "user_id": user_id,
            "old_role": old_role,
            "new_role": new_role
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500
