from flask import Blueprint, jsonify
from app import db
from app.models.sql_models import Agent, Delivery, Client
from flask_jwt_extended import jwt_required

stats_bp = Blueprint('stats', __name__, url_prefix='/api/stats')

@stats_bp.route('/dashboard', methods=['GET'])
@jwt_required()
def get_dashboard_stats():
    try:
        # 1. Nombre d'agents actifs
        active_agents = Agent.query.filter_by(is_active=True).count()
        
        # 2. Total des livraisons
        deliveries_count = Delivery.query.count()
        
        # 3. Chiffre d'affaires total
        total_revenue = db.session.query(db.func.sum(Delivery.total_amount)).scalar() or 0
        
        # 4. Nombre de clients
        total_clients = Client.query.count()

        return jsonify({
            "active_agents": active_agents,
            "deliveries_count": deliveries_count,
            "revenue": float(total_revenue),
            "total_clients": total_clients
        }), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500