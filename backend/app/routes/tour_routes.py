from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Tour, Delivery
from flask_jwt_extended import jwt_required, get_jwt
from datetime import datetime
from app.utils import log_action
from app.utils.helpers import roles_required

tour_bp = Blueprint('tours', __name__, url_prefix='/api/tours')


@tour_bp.route('/start', methods=['POST'])
@jwt_required()
def start_tour():
    claims = get_jwt()
    
    try:
        
        agent_id = int(str(claims['sub']))
    except (ValueError, KeyError) as e:
        print(f"❌ AUTH ERROR: Invalid token sub: {claims.get('sub')} - {e}")
        return jsonify({"msg": "Token invalide ou Agent ID manquant"}), 400

    data = request.get_json() or {}
    print(f"📥 START TOUR DATA: {data}") 

    
    items_to_load = data.get('items', [])
    
    
    if not items_to_load:
        vitale_old = int(data.get('stock_vitale', 0))
        voltic_old = int(data.get('stock_voltic', 0))
        if vitale_old > 0: items_to_load.append({"product_name": "Vitale", "quantity": vitale_old})
        if voltic_old > 0: items_to_load.append({"product_name": "Voltic", "quantity": voltic_old})

    
    print(f"📦 Stock to load: {items_to_load}")

    try:
        
        active_tour = Tour.query.filter_by(agent_id=agent_id, end_time=None).first()
        if active_tour:
            print(f"⚠️ Tournée déjà active pour agent {agent_id}. Récupération ID: {active_tour.id}")
            return jsonify({
                "msg": "Tournée récupérée", 
                "tour_id": active_tour.id,
                "is_recovery": True
            }), 200
        
        
        from app.models.sql_models import Product, StockItem
        
        for item in items_to_load:
            prod_name = item.get('product_name')
            prod_id = item.get('product_id')
            qty = int(item.get('quantity', 0))
            
            if qty <= 0: continue

            
            product = None
            if prod_id:
                product = Product.query.get(prod_id)
            elif prod_name:
                product = Product.query.filter_by(name=prod_name).first()
            
            if not product:
                print(f"❌ Product not found: {item}")
                continue 

            
            stock = StockItem.query.filter_by(product_id=product.id, location='Entrepôt Principal').first()
            if not stock or stock.available_stock < qty:
                msg = f"Stock insuffisant pour {product.name} ({stock.available_stock if stock else 0} dispo)"
                print(f"❌ {msg}")
                return jsonify({"msg": msg}), 400

        
        new_tour = Tour(
            agent_id=agent_id,
            start_lat=data.get('lat', 0.0),
            start_lng=data.get('lng', 0.0),
            
            stock_vitale_loaded=next((item['quantity'] for item in items_to_load if 'Vitale' in item.get('product_name', '')), 0),
            stock_voltic_loaded=next((item['quantity'] for item in items_to_load if 'Voltic' in item.get('product_name', '')), 0),
            status='in_progress',
            start_time=datetime.utcnow()
        )

        db.session.add(new_tour)
        
        
        for item in items_to_load:
            prod_id = item.get('product_id')
            prod_name = item.get('product_name')
            qty = int(item.get('quantity', 0))
            
            if qty <= 0: continue

            product = None
            if prod_id: product = Product.query.get(prod_id)
            elif prod_name: product = Product.query.filter_by(name=prod_name).first()
            
            if product:
                stock = StockItem.query.filter_by(product_id=product.id, location='Entrepôt Principal').first()
                if stock:
                    stock.available_stock -= qty
                    stock.reserved_stock += qty

        db.session.commit()
        
        
        log_action(
            agent_id=agent_id,
            action="TOUR_STARTED",
            entity_type="tour",
            entity_id=new_tour.id,
            details=f"Tournée démarrée - Chargement: {items_to_load}"
        )
        
        return jsonify({
            "msg": "Tournée démarrée",
            "tour_id": new_tour.id,
            "stock_loaded": items_to_load
        }), 201

    except Exception as e:
        db.session.rollback()
        import traceback
        traceback.print_exc() 
        print(f"❌ CRASH API START TOUR: {str(e)}") 
        return jsonify({"msg": f"Erreur serveur interne: {str(e)}"}), 500


@tour_bp.route('/end', methods=['POST'])
@jwt_required()
def end_tour():
    claims = get_jwt()
    try:
        agent_id = int(claims['sub'])
    except:
        agent_id = claims['sub']

    data = request.get_json()

    
    tour = Tour.query.filter_by(agent_id=agent_id, end_time=None).first()
    if not tour:
        return jsonify({"msg": "Aucune tournée active trouvée"}), 404

    
    tour.end_time = datetime.utcnow()
    tour.end_lat = data.get('lat')
    tour.end_lng = data.get('lng')
    tour.status = 'completed'

    
    
    deliveries = Delivery.query.filter(
        Delivery.agent_id == agent_id,
        Delivery.date >= tour.start_time,
        Delivery.date <= tour.end_time
    ).all()

    
    vitale_qty = 0
    voltic_qty = 0
    total_cash = 0.0
    
    for d in deliveries:
        total_cash += d.total_amount
        for item in d.items:
            
            if 'Vitale' in item.product.name:
                vitale_qty += item.quantity
            elif 'Voltic' in item.product.name:
                voltic_qty += item.quantity

    tour.total_deliveries = len(deliveries)
    tour.total_cash_collected = total_cash
    tour.stock_vitale_delivered = vitale_qty
    tour.stock_voltic_delivered = voltic_qty
    
    
    vitale_restant = tour.stock_vitale_loaded - tour.stock_vitale_delivered
    voltic_restant = tour.stock_voltic_loaded - tour.stock_voltic_delivered
    
    from app.models.sql_models import Product, StockItem
    vitale_product = Product.query.filter_by(name='Vitale').first()
    voltic_product = Product.query.filter_by(name='Voltic').first()
    
    if vitale_product and vitale_restant > 0:
        vitale_stock = StockItem.query.filter_by(product_id=vitale_product.id, location='Entrepôt Principal').first()
        if vitale_stock:
            vitale_stock.available_stock += vitale_restant
            vitale_stock.reserved_stock -= tour.stock_vitale_loaded
    
    if voltic_product and voltic_restant > 0:
        voltic_stock = StockItem.query.filter_by(product_id=voltic_product.id, location='Entrepôt Principal').first()
        if voltic_stock:
            voltic_stock.available_stock += voltic_restant
            voltic_stock.reserved_stock -= tour.stock_voltic_loaded

    db.session.commit()
    
    
    log_action(
        agent_id=agent_id,
        action="TOUR_COMPLETED",
        entity_type="tour",
        entity_id=tour.id,
        details=f"Tournée terminée - Livraisons: {tour.total_deliveries}, Cash: {tour.total_cash_collected}, Stock restitué: Vitale {vitale_restant}, Voltic {voltic_restant}"
    )

    return jsonify({
        "msg": "Tournée terminée",
        "summary": {
            "deliveries": tour.total_deliveries,
            "cash": tour.total_cash_collected,
            "stock_returned": {
                "vitale": vitale_restant,
                "voltic": voltic_restant
            }
        }
    }), 200


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


@tour_bp.route('/vehicle-stock', methods=['GET'])
@jwt_required()
def get_vehicle_stock():
    """Retourne le stock total actuellement en véhicules (tournées in_progress)"""
    try:
        active_tours = Tour.query.filter_by(status='in_progress').all()
        vitale_in_vehicles = sum((t.stock_vitale_loaded - t.stock_vitale_delivered) for t in active_tours)
        voltic_in_vehicles = sum((t.stock_voltic_loaded - t.stock_voltic_delivered) for t in active_tours)
        
        return jsonify({
            "vitale_in_vehicles": vitale_in_vehicles,
            "voltic_in_vehicles": voltic_in_vehicles,
            "active_tours_count": len(active_tours)
        }), 200
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500