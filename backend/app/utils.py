from app import db
from app.models.sql_models import AuditLog
from flask import request
import json

def log_action(user_id=None, agent_id=None, action="", entity_type="", entity_id=None, details=None):
    """
    Enregistre une action dans la table audit_logs.
    """
    try:
        # Conversion des détails en JSON string si c'est un dict/list
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
        print(f"Erreur lors du logging d'audit: {e}")
        db.session.rollback()
