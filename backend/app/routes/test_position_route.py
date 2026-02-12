from flask import Blueprint, jsonify
from app.models.sql_models import Agent
from flask_jwt_extended import jwt_required

test_bp = Blueprint('test_routes', __name__, url_prefix='/api/test')

@test_bp.route('/last-position', methods=['GET'])
def get_last_positions():
    """
    Route de DEBUG pour vérifier si le GPS arrive bien en base.
    """
    agents = Agent.query.filter(Agent.last_lat.isnot(None)).all()
    results = []
    for a in agents:
        results.append({
            "agent_id": a.id,
            "name": a.full_name,
            "lat": a.last_lat,
            "lng": a.last_lng,
            "last_update": a.last_location_update.strftime("%d/%m/%Y %H:%M:%S") if a.last_location_update else "Jamais"
        })
    
    return jsonify({
        "count": len(results),
        "agents": results
    }), 200
