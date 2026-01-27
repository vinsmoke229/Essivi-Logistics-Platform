from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Tour, Delivery
from flask_jwt_extended import jwt_required, get_jwt
from datetime import datetime
from app.utils import log_action
from app.utils.helpers import roles_required

tour_bp = Blueprint('tours', __name__, url_prefix='/api/tours')

# 1. DÉMARRER UNE TOURNÉE AVEC CHARGEMENT DU STOCK
@tour_bp.route('/start', methods=['POST'])
@jwt_required()
def start_tour():
    claims = get_jwt()
    
    try:
        # Robust conversion of agent_id
        agent_id = int(str(claims['sub']))
    except (ValueError, KeyError) as e:
        print(f"❌ AUTH ERROR: Invalid token sub: {claims.get('sub')} - {e}")
        return jsonify({"msg": "Token invalide ou Agent ID manquant"}), 400

    data = request.get_json() or {}
    print(f"📥 START TOUR DATA: {data}") # Debug data reception

    # Récupérer les quantités à charger
    vitale_to_load = int(data.get('stock_vitale', 0))
    voltic_to_load = int(data.get('stock_voltic', 0))

    try:
        # Vérifier si une tournée est déjà en cours
        active_tour = Tour.query.filter_by(agent_id=agent_id, end_time=None).first()
        if active_tour:
            return jsonify({"msg": "Une tournée est déjà en cours", "tour_id": active_tour.id}), 400
        
        # Vérifier le stock disponible en entrepôt
        # Dynamic import to avoid circular dependency
        from app.models.sql_models import Product, StockItem
        
        # Helper check stock
        def check_stock(product_name, qty_needed):
            if qty_needed <= 0: return True, ""
            prod = Product.query.filter_by(name=product_name).first()
            if not prod: return True, "" # Skip if product doesn't exist
            stock = StockItem.query.filter_by(product_id=prod.id, location='Entrepôt Principal').first()
            if not stock or stock.available_stock < qty_needed:
                return False, f"Stock {product_name} insuffisant ({stock.available_stock if stock else 0} dispo)"
            return True, ""

        ok, msg = check_stock('Vitale', vitale_to_load)
        if not ok: return jsonify({"msg": msg}), 400
        
        ok, msg = check_stock('Voltic', voltic_to_load)
        if not ok: return jsonify({"msg": msg}), 400

        # Créer la tournée
        new_tour = Tour(
            agent_id=agent_id,
            start_lat=data.get('lat', 0.0),
            start_lng=data.get('lng', 0.0),
            stock_vitale_loaded=vitale_to_load,
            stock_voltic_loaded=voltic_to_load,
            status='in_progress'
        )

        db.session.add(new_tour)
        
        # DÉDUIRE DU STOCK ENTREPÔT
        if vitale_to_load > 0:
            p = Product.query.filter_by(name='Vitale').first()
            if p:
                s = StockItem.query.filter_by(product_id=p.id, location='Entrepôt Principal').first()
                if s: 
                    s.available_stock -= vitale_to_load
                    s.reserved_stock += vitale_to_load
                
        if voltic_to_load > 0:
            p = Product.query.filter_by(name='Voltic').first()
            if p:
                s = StockItem.query.filter_by(product_id=p.id, location='Entrepôt Principal').first()
                if s: 
                    s.available_stock -= voltic_to_load
                    s.reserved_stock += voltic_to_load

        db.session.commit()
        
        # LOG D'AUDIT
        log_action(
            agent_id=agent_id,
            action="TOUR_STARTED",
            entity_type="tour",
            entity_id=new_tour.id,
            details=f"Tournée démarrée - Vitale: {vitale_to_load}, Voltic: {voltic_to_load}"
        )
        
        return jsonify({
            "msg": "Tournée démarrée",
            "tour_id": new_tour.id,
            "stock_loaded": {
                "vitale": vitale_to_load,
                "voltic": voltic_to_load
            }
        }), 201

    except Exception as e:
        db.session.rollback()
        import traceback
        traceback.print_exc() # Print full stack trace to console
        print(f"❌ CRASH API START TOUR: {str(e)}") 
        return jsonify({"msg": f"Erreur serveur interne: {str(e)}"}), 500

# 2. TERMINER UNE TOURNÉE ET RESTITUER LE STOCK
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
    tour.status = 'completed'

    # CALCUL AUTOMATIQUE DU BILAN
    deliveries = Delivery.query.filter(
        Delivery.agent_id == agent_id,
        Delivery.date >= tour.start_time,
        Delivery.date <= tour.end_time
    ).all()

    # CALCUL AUTOMATIQUE DU BILAN DYNAMIQUE
    vitale_qty = 0
    voltic_qty = 0
    total_cash = 0.0
    
    for d in deliveries:
        total_cash += d.total_amount
        for item in d.items:
            # On vérifie par nom de produit (Robuste car les noms sont uniques)
            if 'Vitale' in item.product.name:
                vitale_qty += item.quantity
            elif 'Voltic' in item.product.name:
                voltic_qty += item.quantity

    tour.total_deliveries = len(deliveries)
    tour.total_cash_collected = total_cash
    tour.stock_vitale_delivered = vitale_qty
    tour.stock_voltic_delivered = voltic_qty
    
    # RESTITUER LE STOCK NON LIVRÉ À L'ENTREPÔT
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
    
    # LOG D'AUDIT
    log_action(
        agent_id=agent_id,
        action="TOUR_COMPLETED",
        entity_type="tour",
        entity_id=tour.id,
        details=f"Tournée terminée - Livraisons: {tour.total_deliveries}, Stock restitué: Vitale {vitale_restant}, Voltic {voltic_restant}"
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

# 5. OBTENIR LE STOCK VÉHICULE GLOBAL
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