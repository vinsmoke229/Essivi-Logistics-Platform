from app import db
from app.models.sql_models import AuditLog
from flask import request
import json
import math
from functools import wraps
from flask_jwt_extended import get_jwt
from flask import request, jsonify

def roles_required(allowed_roles):
    """
    Décorateur pour restreindre l'accès à certains rôles.
    """
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            claims = get_jwt()
            user_role = claims.get('role')
            user_type = claims.get('type')
            
            
            if user_type == 'agent' and 'agent' not in allowed_roles:
                return jsonify({"msg": "Accès réservé aux administrateurs"}), 403
                
            if user_role not in allowed_roles and 'admin' not in allowed_roles: 
                 
                if user_role == 'super_admin' or claims.get('type') == 'admin':
                    return fn(*args, **kwargs)
                return jsonify({"msg": f"Action non autorisée pour le rôle : {user_role}"}), 403
            
            return fn(*args, **kwargs)
        return wrapper
    return decorator

def log_action(user_id=None, agent_id=None, action="", entity_type="", entity_id=None, details=None):
    """
    Enregistre une action dans la table audit_logs (SQL).
    Assure que les IDs sont des entiers pour Postgres.
    """
    try:
        
        def to_int(v):
            try: return int(v) if v is not None else None
            except: return None

        user_id = to_int(user_id)
        agent_id = to_int(agent_id)
        entity_id = to_int(entity_id)

        
        details_str = details
        if isinstance(details, (dict, list)):
            details_str = json.dumps(details, ensure_ascii=False)
            
        log = AuditLog(
            user_id=user_id,
            agent_id=agent_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            details=details_str,
            ip_address=request.remote_addr if request else None
        )
        db.session.add(log)
        db.session.commit()
    except Exception as e:
        print(f"❌ Erreur lors du logging d'audit SQL: {str(e)}")
        db.session.rollback()

def haversine_distance(lat1, lon1, lat2, lon2):
    """
    Calcule la distance entre deux points GPS en kilomètres.
    """
    
    R = 6371.0
    
    
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    distance = R * c
    return distance
