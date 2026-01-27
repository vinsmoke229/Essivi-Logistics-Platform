from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Order, Client, Agent
from flask_jwt_extended import jwt_required, get_jwt
from datetime import datetime
from app.utils import haversine_distance

order_bp = Blueprint('orders', __name__, url_prefix='/api/orders')

# 1. CRÉER UNE COMMANDE
@order_bp.route('/', methods=['POST'])
@jwt_required()
def create_order():
    claims = get_jwt()
    data = request.get_json()

    if not data:
        return jsonify({"msg": "Aucune donnée reçue"}), 400

    # Déterminer le client_id
    if claims.get('type') == 'admin':
        client_id = int(data.get('client_id')) if data.get('client_id') else None
    else:
        client_id = int(str(claims['sub']))

    if not client_id:
        return jsonify({"msg": "ID Client manquant"}), 400

    try:
        # Création de la commande de base
        new_order = Order(
            client_id=client_id,
            preferred_delivery_time=data.get('preferred_time', ''),
            instructions=data.get('instructions', ''),
            status='pending',
            created_at=datetime.utcnow()
        )
        db.session.add(new_order)
        db.session.flush() # Pour avoir l'id

        from app.models.sql_models import OrderItem, Product
        items_data = data.get('items', [])
        
        # Support pour vieux format si besoin
        if not items_data:
            if 'quantity_vitale' in data and int(data['quantity_vitale']) > 0:
                p = Product.query.filter_by(name='Vitale').first()
                if p: items_data.append({'product_id': p.id, 'quantity': int(data['quantity_vitale'])})
            if 'quantity_voltic' in data and int(data['quantity_voltic']) > 0:
                p = Product.query.filter_by(name='Voltic').first()
                if p: items_data.append({'product_id': p.id, 'quantity': int(data['quantity_voltic'])})

        for item in items_data:
            new_item = OrderItem(
                order_id=new_order.id,
                product_id=item.get('product_id'),
                quantity=item.get('quantity')
            )
            db.session.add(new_item)

        db.session.commit()
        return jsonify({"msg": "Commande passée avec succès", "id": new_order.id}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# 2. LISTER LES COMMANDES
@order_bp.route('/', methods=['GET'])
@jwt_required()
def get_orders():
    claims = get_jwt()
    user_type = claims.get('type')
    user_id = int(claims['sub'])

    if user_type == 'admin':
        orders = Order.query.order_by(Order.created_at.desc()).all()
    elif user_type == 'client':
        orders = Order.query.filter_by(client_id=user_id).order_by(Order.created_at.desc()).all()
    else: # Agent
        orders = Order.query.filter_by(agent_id=user_id).order_by(Order.created_at.desc()).all()

    result = []
    for o in orders:
        items_summary = []
        for item in o.items:
            items_summary.append({
                "product_name": item.product.name if item.product else "Inconnu",
                "quantity": item.quantity
            })
        
        items_str = ", ".join([f"{i['product_name']} ({i['quantity']})" for i in items_summary])

        result.append({
            "id": str(o.id),
            "client_name": o.client.name if o.client else "Inconnu",
            "status": o.status,
            "created_at": o.created_at.strftime("%d/%m/%Y %H:%M"),
            "items_description": items_str,
            "items": items_summary,
            "agent_id": o.agent_id,
            "assigned_agent_name": o.agent.full_name if o.agent else None,
            "quantity_vitale": 0, # Legacy
            "quantity_voltic": 0  # Legacy
        })
    
    return jsonify(result), 200

# 3. ASSIGNER UNE COMMANDE (ADMIN)
@order_bp.route('/<int:id>/assign', methods=['PUT'])
@jwt_required()
def assign_order(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Action réservée aux administrateurs"}), 403

    order = Order.query.get_or_404(id)
    data = request.get_json()
    agent_id = data.get('agent_id')

    if not agent_id:
        return jsonify({"msg": "ID Agent requis"}), 400

    try:
        order.agent_id = int(agent_id)
        order.status = 'accepted'
        db.session.commit()

        # NOTIFICATION AGENT
        try:
            from app.services.notification_service import notification_service
            agent = Agent.query.get(order.agent_id)
            if agent:
                total_est = sum([i.quantity * (i.product.price if i.product else 0) for i in order.items])
                items_text = ", ".join([f"{i.product.name if i.product else 'Inconnu'} x{i.quantity}" for i in order.items])
                
                delivery_data = {
                    "id": order.id,
                    "client_name": order.client.name if order.client else "Client inconnu",
                    "agent_name": agent.full_name,
                    "total_amount": total_est,
                    "items_summary": items_text
                }
                notification_service.send_delivery_notification(
                    agent_email=agent.email,
                    agent_phone=agent.phone,
                    delivery_info=delivery_data
                )
        except Exception as ne:
            print(f"⚠️ Erreur notification: {ne}")

        return jsonify({"msg": "Commande assignée avec succès"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# 3.1 SUGGESTION D'AGENTS PAR PROXIMITÉ
@order_bp.route('/<int:id>/suggest-agents', methods=['GET'])
@jwt_required()
def suggest_agents(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Réservé aux administrateurs"}), 403

    order = Order.query.get_or_404(id)
    if not order.client or order.client.gps_lat is None or order.client.gps_lng is None:
        return jsonify({"msg": "Coordonnées GPS client manquantes"}), 400

    from app.utils import haversine_distance
    client_lat = order.client.gps_lat
    client_lng = order.client.gps_lng

    agents = Agent.query.filter(Agent.is_active == True, Agent.last_lat.isnot(None)).all()
    suggestions = []
    for agent in agents:
        dist = haversine_distance(client_lat, client_lng, agent.last_lat, agent.last_lng)
        suggestions.append({
            "id": agent.id,
            "full_name": agent.full_name,
            "distance_km": round(dist, 2),
            "phone": agent.phone
        })
    suggestions.sort(key=lambda x: x['distance_km'])
    return jsonify(suggestions[:5]), 200

# 4. RÉCUPÉRER MES MISSIONS (AGENT)
@order_bp.route('/my-missions', methods=['GET'])
@jwt_required()
def get_my_missions():
    claims = get_jwt()
    if claims.get('type') != 'agent':
         return jsonify({"msg": "Accès réservé aux agents"}), 403

    agent_id = int(claims['sub'])
    orders = Order.query.filter_by(agent_id=agent_id, status='accepted').all()
    
    result = []
    for o in orders:
        total_price = sum([i.quantity * (i.product.price if i.product else 0) for i in o.items])
        result.append({
            "order_id": str(o.id),
            "client_id": str(o.client_id),
            "client_name": o.client.name if o.client else "Inconnu",
            "client_phone": o.client.phone if o.client else "--",
            "client_address": o.client.address if o.client else "--",
            "gps_lat": o.client.gps_lat if o.client else None,
            "gps_lng": o.client.gps_lng if o.client else None,
            "items": [{"product_id": i.product_id, "name": i.product.name if i.product else "Inconnu", "quantity": i.quantity} for i in o.items],
            "total_amount": total_price, 
            "instructions": o.instructions
        })
    return jsonify(result), 200

# 5. MODIFIER UNE COMMANDE (ADMIN)
@order_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_order(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Action réservée aux administrateurs"}), 403

    order = Order.query.get_or_404(id)
    data = request.get_json()

    if 'status' in data: order.status = data['status']
    if 'instructions' in data: order.instructions = data['instructions']
    
    # Mise à jour des articles si fournis
    if 'items' in data:
        from app.models.sql_models import OrderItem
        # Suppression des anciens items
        OrderItem.query.filter_by(order_id=order.id).delete()
        # Ajout des nouveaux
        for item in data['items']:
            new_item = OrderItem(
                order_id=order.id,
                product_id=item.get('product_id'),
                quantity=item.get('quantity')
            )
            db.session.add(new_item)

    try:
        db.session.commit()
        return jsonify({"msg": "Commande mise à jour"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500

# 6. SUPPRIMER UNE COMMANDE (ADMIN)
@order_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_order(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Action réservée aux administrateurs"}), 403

    order = Order.query.get_or_404(id)
    try:
        db.session.delete(order)
        db.session.commit()
        return jsonify({"msg": "Commande supprimée"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur : {str(e)}"}), 500
