from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Evaluation, Delivery, Agent
from flask_jwt_extended import jwt_required, get_jwt
from datetime import datetime

eval_bp = Blueprint('evaluations', __name__, url_prefix='/api/evaluations')

@eval_bp.route('/', methods=['POST'])
@jwt_required()
def create_evaluation():
    claims = get_jwt()
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    data = request.get_json()
    rating = data.get('rating')
    comment = data.get('comment', '')
    delivery_id = data.get('delivery_id')
    client_id = int(claims['sub'])

    if not rating or not delivery_id:
        return jsonify({"msg": "Note et ID livraison requis"}), 400

    
    delivery = Delivery.query.filter_by(id=delivery_id, client_id=client_id, status='completed').first()
    if not delivery:
        return jsonify({"msg": "Livraison non trouvée ou non éligible à évaluation"}), 404

    
    existing = Evaluation.query.filter_by(delivery_id=delivery_id).first()
    if existing:
        return jsonify({"msg": "Cette livraison a déjà été évaluée"}), 400

    try:
        new_eval = Evaluation(
            rating=rating,
            comment=comment,
            delivery_id=delivery_id,
            client_id=client_id,
            created_at=datetime.utcnow()
        )
        db.session.add(new_eval)
        
        
        agent = Agent.query.get(delivery.agent_id)
        if agent:
            all_evals = Evaluation.query.join(Delivery).filter(Delivery.agent_id == agent.id).all()
            total_ratings = sum([e.rating for e in all_evals]) + rating
            count = len(all_evals) + 1
            agent.average_rating = total_ratings / count

        db.session.commit()
        return jsonify({"msg": "Évaluation enregistrée avec succès"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500
