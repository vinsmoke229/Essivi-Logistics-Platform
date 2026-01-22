from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Tour, Delivery
from flask_jwt_extended import jwt_required, get_jwt
from datetime import datetime

tour_bp = Blueprint('tours', __name__, url_prefix='/api/tours')

# 1. DÉMARRER UNE TOURNÉE
@tour_bp.route('/start', methods=['POST'])
@jwt_required()
def start_tour():
    claims = get_jwt()
    try:
        agent_id = int(claims['sub'])
    except:
        agent_id = claims['sub']

    data = request.get_json()

    # Vérifier si une tournée est déjà en cours (non terminée)
    active_tour = Tour.query.filter_by(agent_id=agent_id, end_time=None).first()
    if active_tour:
        return jsonify({"msg": "Une tournée est déjà en cours", "tour_id": active_tour.id}), 400

    new_tour = Tour(
        agent_id=agent_id,
        start_lat=data.get('lat'),
        start_lng=data.get('lng')
    )

    db.session.add(new_tour)
    db.session.commit()

    return jsonify({"msg": "Tournée démarrée", "tour_id": new_tour.id}), 201

# 2. TERMINER UNE TOURNÉE (Et faire le bilan)
@tour_bp.route('/end', methods=['POST'])
@jwt_required()
def end_tour():
    claims = get_jwt()
    try:
        agent_id = int(claims['sub'])
    except:
        agent_id = claims['sub']

    data = request.get_json()

    # Trouver la tournée active
    tour = Tour.query.filter_by(agent_id=agent_id, end_time=None).first()
    if not tour:
        return jsonify({"msg": "Aucune tournée active trouvée"}), 404

    # Clôturer la tournée
    tour.end_time = datetime.utcnow()
    tour.end_lat = data.get('lat')
    tour.end_lng = data.get('lng')

    # CALCUL AUTOMATIQUE DU BILAN (Bonus "Automatisation" du cahier des charges)
    # On compte les livraisons faites PENDANT cette tournée
    deliveries = Delivery.query.filter(
        Delivery.agent_id == agent_id,
        Delivery.date >= tour.start_time,
        Delivery.date <= tour.end_time
    ).all()

    tour.total_deliveries = len(deliveries)
    tour.total_cash_collected = sum(d.total_amount for d in deliveries)

    db.session.commit()

    return jsonify({
        "msg": "Tournée terminée",
        "summary": {
            "deliveries": tour.total_deliveries,
            "cash": tour.total_cash_collected
        }
    }), 200

# 3. LISTER TOUTES LES TOURNÉES (Pour l'admin)
@tour_bp.route('', methods=['GET'])
@jwt_required()
def get_all_tours():
    from app.models.sql_models import Agent
    tours = db.session.query(Tour, Agent.full_name).join(Agent, Tour.agent_id == Agent.id).all()
    
    results = []
    for tour, agent_name in tours:
        results.append({
            "id": tour.id,
            "agent_id": tour.agent_id,
            "agent_name": agent_name,
            "start_time": tour.start_time.isoformat() if tour.start_time else None,
            "end_time": tour.end_time.isoformat() if tour.end_time else None,
            "total_deliveries": tour.total_deliveries,
            "total_cash_collected": tour.total_cash_collected,
            "start_lat": tour.start_lat,
            "start_lng": tour.start_lng,
            "end_lat": tour.end_lat,
            "end_lng": tour.end_lng
        })
    
    return jsonify(results), 200

# 4. LIRE UNE TOURNÉE PAR ID
@tour_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_tour(id):
    from app.models.sql_models import Agent
    tour = Tour.query.get_or_404(id)
    agent = Agent.query.get(tour.agent_id)
    
    return jsonify({
        "id": tour.id,
        "agent_id": tour.agent_id,
        "agent_name": agent.full_name if agent else "Inconnu",
        "start_time": tour.start_time.isoformat() if tour.start_time else None,
        "end_time": tour.end_time.isoformat() if tour.end_time else None,
        "total_deliveries": tour.total_deliveries,
        "total_cash_collected": tour.total_cash_collected,
        "start_lat": tour.start_lat,
        "start_lng": tour.start_lng,
        "end_lat": tour.end_lat,
        "end_lng": tour.end_lng
    }), 200