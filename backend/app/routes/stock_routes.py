from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt
from app import db
from app.models.sql_models import StockItem, StockMovement, Product, VehicleStock, Delivery, Agent, Client
from datetime import datetime
import math
import traceback
from app.utils import log_action


try:
    from app.services.notification_service import notification_service
except ImportError:
    notification_service = None

stock_bp = Blueprint('stock', __name__, url_prefix='/api/stock')


@stock_bp.route('/items', methods=['GET'])
@jwt_required()
def get_stock_items():
    """Récupérer tous les articles de stock réels"""
    try:
        stock_items = StockItem.query.all()
        result = []
        
        for item in stock_items:
            
            status = 'normal'
            if item.available_stock <= item.low_stock_threshold:
                status = 'critical' if item.available_stock == 0 else 'low'
            
            result.append({
                'id': str(item.id),
                'product_name': item.product.name if item.product else 'Inconnu',
                'total_stock': item.total_stock,
                'available_stock': item.available_stock,
                'reserved_stock': item.reserved_stock,
                'unit_price': item.unit_price,
                'unit': item.unit,
                'low_stock_threshold': item.low_stock_threshold,
                'last_restock_date': item.last_restock_date.strftime('%Y-%m-%d') if item.last_restock_date else None,
                'location': item.location,
                'status': status
            })
        
        return jsonify(result), 200
        
    except Exception as e:
        print(f"Error in get_stock_items: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/movements', methods=['GET'])
@jwt_required()
def get_stock_movements():
    """Récupérer les mouvements de stock"""
    try:
        movements = StockMovement.query.order_by(StockMovement.timestamp.desc()).limit(100).all()
        result = []
        
        for movement in movements:
            result.append({
                'id': str(movement.id),
                'product_id': str(movement.stock_item.product_id) if movement.stock_item else None,
                'product_name': movement.stock_item.product.name if movement.stock_item and movement.stock_item.product else 'Inconnu',
                'movement_type': movement.movement_type,
                'quantity': movement.quantity,
                'reference': movement.reference,
                'agent_name': movement.agent.full_name if movement.agent else 'Système',
                'client_name': movement.client.name if movement.client else '',
                'timestamp': movement.timestamp.strftime('%Y-%m-%dT%H:%M:%S') if movement.timestamp else datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
                'notes': movement.notes or ''
            })
        
        return jsonify(result), 200
    except Exception as e:
        print(f"Error in get_stock_movements: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/vehicles', methods=['GET'])
@jwt_required()
def get_vehicle_stock():
    """Récupérer le stock par véhicule"""
    try:
        vehicle_stocks = VehicleStock.query.all()
        result = []
        
        for vs in vehicle_stocks:
            result.append({
                'id': str(vs.id),
                'vehicle_id': str(vs.agent_id),
                'vehicle_name': f'Tricycle {vs.agent.tricycle_plate or "Non immatriculé"}' if vs.agent else 'Inconnu',
                'agent_name': vs.agent.full_name if vs.agent else 'Inconnu',
                'product_id': str(vs.product_id),
                'product_name': vs.product.name if vs.product else 'Inconnu',
                'current_stock': vs.current_stock,
                'max_capacity': vs.max_capacity,
                'last_updated': vs.last_updated.strftime('%Y-%m-%dT%H:%M:%S') if vs.last_updated else datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
                'status': vs.status
            })
        
        return jsonify(result), 200
    except Exception as e:
        print(f"Error in get_vehicle_stock: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/alerts', methods=['GET'])
@jwt_required()
def get_stock_alerts():
    """Récupérer les alertes de stock"""
    try:
        low_stock_items = StockItem.query.filter(
            StockItem.available_stock <= StockItem.low_stock_threshold
        ).all()
        
        alerts = []
        for item in low_stock_items:
            alert_type = 'critical' if item.available_stock == 0 else 'low'
            alerts.append({
                'id': str(item.id),
                'product_id': str(item.product_id),
                'product_name': item.product.name if item.product else 'Inconnu',
                'current_stock': item.available_stock,
                'threshold': item.low_stock_threshold,
                'alert_type': alert_type,
                'created_at': item.updated_at.strftime('%Y-%m-%dT%H:%M:%S') if item.updated_at else datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
                'resolved': False
            })
        
        return jsonify(alerts), 200
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/items', methods=['POST'])
@jwt_required()
def create_stock_item():
    """Créer un nouvel article de stock"""
    try:
        data = request.get_json()
        
        
        product = Product.query.filter_by(name=data.get('product_name')).first()
        if not product:
            product = Product(
                name=data.get('product_name'),
                price=float(data.get('unit_price', 0)),
                is_active=True
            )
            db.session.add(product)
            db.session.flush()  
        
        
        stock_item = StockItem(
            product_id=product.id,
            location=data.get('location', 'Entrepôt Principal'),
            total_stock=int(data.get('total_stock', 0)),
            available_stock=int(data.get('available_stock', data.get('total_stock', 0))),
            reserved_stock=int(data.get('reserved_stock', 0)),
            unit_price=float(data.get('unit_price', 0)),
            unit=data.get('unit', 'unités'),
            low_stock_threshold=int(data.get('low_stock_threshold', 10)),
            last_restock_date=datetime.now()
        )
        
        db.session.add(stock_item)
        db.session.flush()

        
        initial_movement = StockMovement(
            stock_item_id=stock_item.id,
            movement_type='in',
            quantity=stock_item.total_stock,
            reference='INITIAL_STOCK',
            notes='Stock initial',
            timestamp=datetime.now()
        )
        db.session.add(initial_movement)
        
        db.session.commit()
        
        
        claims = get_jwt()
        log_action(
            user_id=int(claims.get('sub')) if isinstance(claims.get('sub'), str) and claims.get('sub').isdigit() else claims.get('sub'),
            action="CREATE_STOCK_ITEM",
            entity_type="stock_item",
            entity_id=stock_item.id,
            details=data
        )
        
        return jsonify({
            "id": str(stock_item.id),
            "product_name": product.name,
            "msg": "Article de stock créé avec succès"
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"Error in create_stock_item: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/restock', methods=['POST'])
@jwt_required()
def restock_product():
    """Réapprovisionner un produit"""
    try:
        data = request.get_json()
        
        
        stock_item_id = int(data.get('product_id')) if data.get('product_id') else None
        
        if not stock_item_id:
            
            stock_item_id = int(data.get('stock_item_id')) if data.get('stock_item_id') else None

        stock_item = StockItem.query.get(stock_item_id)
        if not stock_item:
            return jsonify({"msg": "Article de stock non trouvé"}), 404
        
        quantity = int(data.get('quantity', 0))
        if quantity <= 0:
            return jsonify({"msg": "Quantité invalide"}), 400
        
        
        stock_item.total_stock += quantity
        stock_item.available_stock += quantity
        stock_item.last_restock_date = datetime.now()
        
        
        movement = StockMovement(
            stock_item_id=stock_item.id,
            movement_type='in',
            quantity=quantity,
            reference=data.get('reference', f'RESTOCK-{datetime.now().strftime("%Y%m%d%H%M")}'),
            notes=data.get('notes', f'Réapprovisionnement de {quantity} unités'),
            timestamp=datetime.now()
        )
        db.session.add(movement)
        db.session.commit()
        
        
        claims = get_jwt()
        log_action(
            user_id=claims.get('sub'),
            action="RESTOCK_PRODUCT",
            entity_type="stock_item",
            entity_id=stock_item.id,
            details=data
        )
        
        
        if notification_service and stock_item.available_stock <= stock_item.low_stock_threshold:
            notification_service.send_low_stock_alert(
                admin_email="admin@essivi.com", 
                product_info={
                    "product_name": stock_item.product.name,
                    "current_stock": stock_item.available_stock,
                    "threshold": stock_item.low_stock_threshold
                }
            )

        return jsonify({
            "msg": "Produit réapprovisionné avec succès",
            "new_total_stock": stock_item.total_stock,
            "new_available_stock": stock_item.available_stock
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"Error in restock_product: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/movements/out', methods=['POST'])
@jwt_required()
def create_out_movement():
    """Créer un mouvement de sortie de stock"""
    try:
        data = request.get_json()
        
        stock_item_id = int(data.get('stock_item_id'))
        stock_item = StockItem.query.get(stock_item_id)
        if not stock_item:
            return jsonify({"msg": "Article de stock non trouvé"}), 404
        
        quantity = int(data.get('quantity', 0))
        if quantity <= 0:
            return jsonify({"msg": "Quantité invalide"}), 400
        
        if stock_item.available_stock < quantity:
            return jsonify({"msg": "Stock insuffisant"}), 400
        
        
        stock_item.available_stock -= quantity
        stock_item.reserved_stock = max(0, stock_item.reserved_stock - quantity)
        
        
        movement = StockMovement(
            stock_item_id=stock_item.id,
            movement_type='out',
            quantity=quantity,
            reference=data.get('reference'),
            agent_id=data.get('agent_id'),
            client_id=data.get('client_id'),
            notes=data.get('notes', f'Sortie de {quantity} unités'),
            timestamp=datetime.now()
        )
        db.session.add(movement)
        db.session.commit()
        
        
        claims = get_jwt()
        log_action(
            user_id=claims.get('sub'),
            action="STOCK_OUT",
            entity_type="stock_item",
            entity_id=stock_item.id,
            details=data
        )
        
        
        if notification_service and stock_item.available_stock <= stock_item.low_stock_threshold:
            notification_service.send_low_stock_alert(
                admin_email="admin@essivi.com",
                product_info={
                    "product_name": stock_item.product.name,
                    "current_stock": stock_item.available_stock,
                    "threshold": stock_item.low_stock_threshold
                }
            )

        return jsonify({
            "msg": "Sortie de stock enregistrée avec succès",
            "new_available_stock": stock_item.available_stock
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"Error in create_out_movement: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/stats', methods=['GET'])
@jwt_required()
def get_stock_stats():
    """Récupérer les statistiques de stock"""
    try:
        products_count = Product.query.filter_by(is_active=True).count()
        total_deliveries = Delivery.query.count()
        
        stock_items = StockItem.query.all()
        total_value = sum(item.total_stock * item.unit_price for item in stock_items)
        low_stock_count = sum(1 for item in stock_items if item.available_stock <= item.low_stock_threshold)

        return jsonify({
            'total_value': total_value,
            'total_products': products_count,
            'low_stock_count': low_stock_count,
            'movements_count': total_deliveries,
            'top_products': [] 
        }), 200
        
    except Exception as e:
        print(f"Error in get_stock_stats: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/alerts/<int:alert_id>/resolve', methods=['PATCH'])
@jwt_required()
def resolve_stock_alert(alert_id):
    """Résoudre une alerte de stock"""
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403
    
    try:
        
        log_action(
            user_id=claims.get('sub'),
            action="RESOLVE_STOCK_ALERT",
            entity_type="stock_alert",
            entity_id=alert_id,
            details={"alert_id": alert_id}
        )
        
        return jsonify({"msg": "Alerte résolue avec succès"}), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/items/<int:id>', methods=['GET'])
@jwt_required()
def get_stock_item(id):
    """Récupérer un article de stock spécifique"""
    try:
        stock_item = StockItem.query.get(id)
        if not stock_item:
            return jsonify({"msg": "Article non trouvé"}), 404
        
        return jsonify({
            'id': str(stock_item.id),
            'product_id': str(stock_item.product_id),
            'product_name': stock_item.product.name if stock_item.product else 'Inconnu',
            'total_stock': stock_item.total_stock,
            'available_stock': stock_item.available_stock,
            'reserved_stock': stock_item.reserved_stock,
            'unit_price': float(stock_item.unit_price),
            'unit': stock_item.unit,
            'low_stock_threshold': stock_item.low_stock_threshold,
            'last_restock_date': stock_item.last_restock_date.strftime('%Y-%m-%d') if stock_item.last_restock_date else None,
            'location': stock_item.location,
            'status': 'normal' if stock_item.available_stock > stock_item.low_stock_threshold else 'low'
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/items/<int:id>', methods=['PUT'])
@jwt_required()
def update_stock_item(id):
    """Mettre à jour un article de stock"""
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403
    
    try:
        stock_item = StockItem.query.get(id)
        if not stock_item:
            return jsonify({"msg": "Article non trouvé"}), 404
        
        data = request.get_json()
        
        if 'product_name' in data:
            if stock_item.product:
                stock_item.product.name = data['product_name']
        
        if 'unit_price' in data: stock_item.unit_price = float(data['unit_price'])
        if 'total_stock' in data: stock_item.total_stock = int(data['total_stock'])
        if 'available_stock' in data: stock_item.available_stock = int(data['available_stock'])
        if 'reserved_stock' in data: stock_item.reserved_stock = int(data['reserved_stock'])
        if 'low_stock_threshold' in data: stock_item.low_stock_threshold = int(data['low_stock_threshold'])
        if 'location' in data: stock_item.location = data['location']
        if 'unit' in data: stock_item.unit = data['unit']
        
        db.session.commit()
        
        
        log_action(
            user_id=claims.get('sub'),
            action="UPDATE_STOCK_ITEM",
            entity_type="stock_item",
            entity_id=id,
            details=data
        )
        
        
        return jsonify({
            'id': str(stock_item.id),
            'product_name': stock_item.product.name if stock_item.product else 'Inconnu',
            'total_stock': stock_item.total_stock,
            'available_stock': stock_item.available_stock,
            'reserved_stock': stock_item.reserved_stock,
            'unit_price': stock_item.unit_price,
            'unit': stock_item.unit,
            'low_stock_threshold': stock_item.low_stock_threshold,
            'location': stock_item.location,
            'status': 'normal' if stock_item.available_stock > stock_item.low_stock_threshold else 'low'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"Error in update_stock_item: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500


@stock_bp.route('/items/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_stock_item(id):
    """Supprimer un article de stock"""
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403
    
    try:
        stock_item = StockItem.query.get(id)
        if not stock_item:
            return jsonify({"msg": "Article non trouvé"}), 404
        
        product_name = stock_item.product.name if stock_item.product else 'Inconnu'
        
        
        StockMovement.query.filter_by(stock_item_id=stock_item.id).delete()
        
        db.session.delete(stock_item)
        db.session.commit()
        
        
        log_action(
            user_id=claims.get('sub'),
            action="DELETE_STOCK_ITEM",
            entity_type="stock_item",
            entity_id=id,
            details={"product_name": product_name}
        )
        
        return jsonify({"msg": "Article supprimé avec succès"}), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"Error in delete_stock_item: {traceback.format_exc()}")
        return jsonify({"msg": f"Erreur suppression: {str(e)}"}), 500


@stock_bp.route('/vehicles/<int:vehicle_id>/products/<int:product_id>', methods=['PUT'])
@jwt_required()
def update_vehicle_stock(vehicle_id, product_id):
    """Mettre à jour le stock d'un véhicule"""
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403
    
    try:
        data = request.get_json()
        
        log_action(
            user_id=claims.get('sub'),
            action="UPDATE_VEHICLE_STOCK",
            entity_type="vehicle_stock",
            entity_id=vehicle_id,
            details=data
        )
        
        return jsonify({
            "msg": "Stock du véhicule mis à jour (simulé)",
            "vehicle_id": vehicle_id,
            "product_id": product_id,
            "current_stock": data.get('current_stock')
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500
