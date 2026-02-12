from flask import Blueprint, jsonify
from app import db
from app.models.sql_models import AuditLog
from flask_jwt_extended import jwt_required, get_jwt
from app.utils.helpers import roles_required

audit_bp = Blueprint('audit', __name__, url_prefix='/api/audit')

@audit_bp.route('/', methods=['GET'])
@jwt_required()
def get_logs():
    
    claims = get_jwt()
    if claims.get('role') != 'super_admin' and claims.get('role') != 'admin':
        return jsonify({"msg": "Accès refusé"}), 403

    logs = AuditLog.query.order_by(AuditLog.timestamp.desc()).limit(200).all()
    
    results = []
    for log in logs:
        
        user_name = "Système"
        if log.user:
            user_name = log.user.username
        elif log.agent:
            user_name = log.agent.full_name

        results.append({
            "id": log.id,
            "user": user_name,
            "action": log.action,
            "module": log.entity_type or "Général",
            "timestamp": log.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            "details": log.details,
            "ip": log.ip_address,
            "status": "Success" 
        })

    return jsonify(results), 200

@audit_bp.route('/', methods=['DELETE'])
@jwt_required()
@roles_required(['super_admin'])  
def delete_all_logs():
    """
    Réinitialise tous les logs d'audit (ATTENTION : Action irréversible)
    """
    try:
        
        num_deleted = AuditLog.query.delete()
        db.session.commit()
        
        return jsonify({
            "msg": f"{num_deleted} logs supprimés avec succès",
            "deleted_count": num_deleted
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500
