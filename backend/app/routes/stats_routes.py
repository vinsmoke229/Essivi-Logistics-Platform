from flask import Blueprint, jsonify, request
from app import db
from app.models.sql_models import Agent, Delivery, Client, Tour
from flask_jwt_extended import jwt_required
from datetime import datetime, timedelta
from sqlalchemy import func, extract

stats_bp = Blueprint('stats', __name__, url_prefix='/api/stats')

@stats_bp.route('/dashboard', methods=['GET'])
@jwt_required()
def get_dashboard_stats():
    try:
        # Période actuelle (mois en cours)
        now = datetime.utcnow()
        current_month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_month_start = (current_month_start - timedelta(days=32)).replace(day=1)
        
        # 1. Revenu mensuel et variation
        current_month_revenue = db.session.query(func.sum(Delivery.total_amount)).filter(
            Delivery.date >= current_month_start
        ).scalar() or 0
        
        last_month_revenue = db.session.query(func.sum(Delivery.total_amount)).filter(
            Delivery.date >= last_month_start,
            Delivery.date < current_month_start
        ).scalar() or 0
        
        revenue_change = ((current_month_revenue - last_month_revenue) / last_month_revenue * 100) if last_month_revenue > 0 else 0
        
        # 2. Livraisons mensuelles et variation
        current_month_deliveries = Delivery.query.filter(
            Delivery.date >= current_month_start
        ).count()
        
        last_month_deliveries = Delivery.query.filter(
            Delivery.date >= last_month_start,
            Delivery.date < current_month_start
        ).count()
        
        deliveries_change = ((current_month_deliveries - last_month_deliveries) / last_month_deliveries * 100) if last_month_deliveries > 0 else 0
        
        # 3. Nouveaux clients et variation
        current_month_clients = Client.query.filter(
            Client.created_at >= current_month_start
        ).count()
        
        last_month_clients = Client.query.filter(
            Client.created_at >= last_month_start,
            Client.created_at < current_month_start
        ).count()
        
        clients_change = ((current_month_clients - last_month_clients) / last_month_clients * 100) if last_month_clients > 0 else 0
        
        # 4. Taux de retour (livraisons annulées / total livraisons)
        total_deliveries = Delivery.query.count()
        cancelled_deliveries = Delivery.query.filter_by(status='cancelled').count()
        return_rate = (cancelled_deliveries / total_deliveries * 100) if total_deliveries > 0 else 0

        return jsonify({
            "monthly_revenue": float(current_month_revenue),
            "monthly_revenue_change": round(revenue_change, 1),
            "total_deliveries": current_month_deliveries,
            "deliveries_change": round(deliveries_change, 1),
            "new_clients": current_month_clients,
            "clients_change": round(clients_change, 1),
            "return_rate": round(return_rate, 1)
        }), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@stats_bp.route('/revenue/monthly', methods=['GET'])
@jwt_required()
def get_monthly_revenue():
    try:
        year = request.args.get('year', datetime.utcnow().year, type=int)
        
        # Revenus mensuels pour l'année spécifiée
        monthly_data = db.session.query(
            extract('month', Delivery.date).label('month'),
            func.sum(Delivery.total_amount).label('revenue')
        ).filter(
            extract('year', Delivery.date) == year
        ).group_by(
            extract('month', Delivery.date)
        ).order_by('month').all()
        
        # Mapper les numéros de mois aux noms
        month_names = ["Jan", "Fev", "Mar", "Avr", "Mai", "Juin", "Juil", "Août", "Sep", "Oct", "Nov", "Dec"]
        result = []
        
        # Créer un dictionnaire pour les données
        data_dict = {int(month): float(revenue) for month, revenue in monthly_data}
        
        # Ajouter tous les mois (même ceux avec 0 revenu)
        for i in range(1, 13):
            result.append({
                "month": month_names[i-1],
                "revenue": data_dict.get(i, 0)
            })
        
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@stats_bp.route('/delivery-status', methods=['GET'])
@jwt_required()
def get_delivery_status_stats():
    try:
        # Statistiques des statuts de livraison
        status_data = db.session.query(
            Delivery.status,
            func.count(Delivery.id).label('count')
        ).group_by(Delivery.status).all()
        
        total_deliveries = Delivery.query.count()
        result = []
        
        for status, count in status_data:
            percentage = (count / total_deliveries * 100) if total_deliveries > 0 else 0
            status_labels = {
                'completed': 'Livré',
                'pending': 'En attente',
                'in_progress': 'En cours',
                'cancelled': 'Annulé'
            }
            
            result.append({
                "status": status_labels.get(status, status),
                "count": count,
                "percentage": round(percentage, 1)
            })
        
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@stats_bp.route('/top-agents', methods=['GET'])
@jwt_required()
def get_top_agents():
    try:
        limit = request.args.get('limit', 5, type=int)
        
        # Performance des agents
        agent_data = db.session.query(
            Agent.id,
            Agent.full_name,
            func.count(Delivery.id).label('deliveries_count'),
            func.sum(Delivery.total_amount).label('total_amount')
        ).outerjoin(
            Delivery, Agent.id == Delivery.agent_id
        ).group_by(
            Agent.id, Agent.full_name
        ).order_by(
            func.count(Delivery.id).desc()
        ).limit(limit).all()
        
        result = []
        for agent_id, agent_name, deliveries_count, total_amount in agent_data:
            result.append({
                "agent_id": agent_id,
                "agent_name": agent_name,
                "deliveries_count": deliveries_count or 0,
                "total_amount": float(total_amount or 0)
            })
        
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@stats_bp.route('/peak-hours', methods=['GET'])
@jwt_required()
def get_peak_hours():
    try:
        period = request.args.get('period', 'month')
        
        # Heures de pointe basées sur les heures de livraison
        hour_data = db.session.query(
            extract('hour', Delivery.date).label('hour'),
            func.count(Delivery.id).label('deliveries_count')
        ).group_by(
            extract('hour', Delivery.date)
        ).order_by('hour').all()
        
        result = []
        for hour, count in hour_data:
            result.append({
                "hour": f"{int(hour)}h-{int(hour)+1}h",
                "deliveries_count": count
            })
        
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": f"Performance error: {str(e)}"}), 500

@stats_bp.route('/performance', methods=['GET'])
@jwt_required()
def get_performance_stats():
    try:
        period = request.args.get('period', 'month')
        
        # Statistiques générales de performance
        total_deliveries = Delivery.query.count()
        total_revenue = db.session.query(func.sum(Delivery.total_amount)).scalar() or 0
        total_agents = Agent.query.count()
        total_clients = Client.query.count()
        
        # Livraisons par statut
        completed_deliveries = Delivery.query.filter_by(status='completed').count()
        completion_rate = (completed_deliveries / total_deliveries * 100) if total_deliveries > 0 else 0
        
        return jsonify({
            "total_deliveries": total_deliveries,
            "total_revenue": float(total_revenue or 0),
            "total_agents": total_agents,
            "total_clients": total_clients,
            "completion_rate": round(completion_rate, 1),
            "average_delivery_value": float(total_revenue / total_deliveries) if total_deliveries > 0 else 0
        }), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500