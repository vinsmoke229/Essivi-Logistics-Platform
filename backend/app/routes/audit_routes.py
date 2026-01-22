from flask import Blueprint, jsonify
from app import db
from app.models.sql_models import AuditLog
from flask_jwt_extended import jwt_required, get_jwt

audit_bp = Blueprint('audit', __name__, url_prefix='/api/audit')

@audit_bp.route('/', methods=['GET'])
@jwt_required()
def get_logs():
    # Seuls les admins peuvent voir les logs d'audit
    claims = get_jwt()
    if claims.get('role') != 'super_admin' and claims.get('role') != 'admin':
        return jsonify({"msg": "Accès refusé"}), 403

    logs = AuditLog.query.order_by(AuditLog.timestamp.desc()).limit(200).all()
    
    results = []
    for log in logs:
        # On essaie de récupérer le nom de l'utilisateur ou de l'agent
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
            "status": "Success" # Pour l'instant on log que les succès dans cette table
        })

    return jsonify(results), 200
