from app.services.audit_service import log_activity
from flask import Blueprint, request, jsonify, current_app
from app import db
from app.models.sql_models import Delivery, Agent, Client, Product, StockItem, StockMovement
from flask_jwt_extended import jwt_required, get_jwt
from app.utils import log_action
from datetime import datetime
import base64
import uuid
import os

delivery_bp = Blueprint('deliveries', __name__, url_prefix='/api/deliveries')


UPLOAD_DELIVERY_FOLDER = 'uploads/deliveries'


def get_delivery_upload_path():
    return os.path.abspath(os.path.join(current_app.root_path, '..', 'uploads', 'deliveries'))

def ensure_delivery_upload_dir():
    path = get_delivery_upload_path()
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path

def format_url(url):
    if not url: return None
    if url.startswith('http'): return url
    path = url[1:] if url.startswith('/') else url
    return f"{request.host_url}{path}"

def save_base64_image(base64_str, prefix):
    if not base64_str or not base64_str.startswith('data:image'):
        return base64_str 
    
    try:
        
        upload_path = ensure_delivery_upload_dir()
        
        format_part, imgstr = base64_str.split(';base64,')
        ext = format_part.split('/')[-1]
        
        
        if ext.lower() not in ['png', 'jpg', 'jpeg']:
            ext = 'png'
            
        filename = f"{prefix}_{uuid.uuid4().hex}.{ext}"
        filepath = os.path.join(upload_path, filename)
        
        with open(filepath, "wb") as fh:
            fh.write(base64.b64decode(imgstr))
            
        
        return f"uploads/deliveries/{filename}"
    except Exception as e:
        print(f"❌ Erreur critique décodage image: {e}")
        
        raise ValueError(f"Échec de l'enregistrement de l'image {prefix}")


@delivery_bp.route('/', methods=['POST'])
@jwt_required()
def create_delivery():
    claims = get_jwt()
    
    try:
        user_id = int(str(claims['sub']))
    except:
        user_id = claims['sub']
        
    user_type = claims.get('type')
    data = request.get_json()
    
    print("Données reçues :", data) 
    
    
    
    if not data or data.get('client_id') is None:
        return jsonify({"msg": "Client requis"}), 400

    
    client_id = int(data['client_id'])
    client = Client.query.get(client_id)
    if not client:
        return jsonify({"msg": "Client introuvable"}), 404

    
    agent_id = user_id if user_type == 'agent' else int(data.get('agent_id')) if data.get('agent_id') else None

    try:
        
        items_data = data.get('items', [])
        
        if not items_data and (data.get('quantity_vitale') or data.get('quantity_voltic')):
             from app.models.sql_models import Product
             p_vitale = Product.query.filter_by(name='Vitale').first()
             p_voltic = Product.query.filter_by(name='Voltic').first()
             if p_vitale and data.get('quantity_vitale'):
                 items_data.append({'product_id': p_vitale.id, 'quantity': int(data['quantity_vitale'])})
             if p_voltic and data.get('quantity_voltic'):
                 items_data.append({'product_id': p_voltic.id, 'quantity': int(data['quantity_voltic'])})
        
        calculated_total = 0.0
        delivery_items_objects = []
        stock_movements = []

        
        photo_path = save_base64_image(data.get('photo_url'), 'photo')
        signature_path = save_base64_image(data.get('signature_url'), 'signature')

        
        new_delivery = Delivery(
            agent_id=agent_id,
            client_id=data['client_id'],
            total_amount=0.0,
            gps_lat_delivery=data.get('gps_lat'), 
            gps_lng_delivery=data.get('gps_lng'),
            photo_url=photo_path,
            signature_url=signature_path,
            status='completed',
            date=datetime.utcnow()
        )
        db.session.add(new_delivery)
        db.session.flush() 

        from app.models.sql_models import DeliveryItem, Product, StockItem, StockMovement

        for item in items_data:
            pid = item.get('product_id')
            qty = int(item.get('quantity', 0))
            if qty <= 0: continue

            product = Product.query.get(pid)
            if not product: continue

            
            line_price = product.price * qty
            calculated_total += line_price

            
            new_item = DeliveryItem(
                delivery_id=new_delivery.id,
                product_id=pid,
                quantity=qty
            )
            db.session.add(new_item)

            
            stock_item = StockItem.query.filter_by(product_id=pid, location='Entrepôt Principal').first()
            if stock_item:
                 
                 
                 stock_item.available_stock -= qty
                 
                 stock_item.reserved_stock = max(0, stock_item.reserved_stock - qty)

                 
                 mv = StockMovement(
                    stock_item_id=stock_item.id,
                    movement_type='out',
                    quantity=qty,
                    reference=f'DEL-{new_delivery.id}',
                    agent_id=agent_id,
                    client_id=client_id,
                    notes=f'Livraison {product.name}'
                 )
                 db.session.add(mv)

        
        
        
        new_delivery.total_amount = calculated_total
        
        db.session.commit()
        
        
        order_id = data.get('order_id')
        if order_id:
            try:
                from app.models.sql_models import Order
                order = Order.query.get(int(order_id))
                if order:
                    order.status = 'completed'
                    db.session.commit()
                    print(f"✅ Mission #{order_id} clôturée automatiquement")
            except Exception as e:
                print(f"⚠️ Erreur clôture mission #{order_id}: {e}")
                
 
        
        log_activity(user_id, user_type, "CREATE_DELIVERY", {"id": new_delivery.id, "amount": calculated_total})
        log_action(user_id=user_id if user_type == 'admin' else None, 
                   agent_id=agent_id if user_type == 'agent' else None,
                   action="CREATE_DELIVERY", entity_type="delivery", 
                   entity_id=new_delivery.id, details=f"Montant: {calculated_total}, Items: {len(items_data)}")

        
        try:
            from app.services.notification_service import notification_service
            
            delivery_data = {
                "id": new_delivery.id,
                "client_name": client.name,
                "agent_name": "Agent",
                "total_amount": new_delivery.total_amount,
                
            }
            
            notification_service.send_delivery_notification(
                agent_email=client.phone + "@sim.com", 
                agent_phone=client.phone,
                delivery_info=delivery_data
            )
        except Exception as e:
            print(f"⚠️ Erreur notification non bloquante: {str(e)}")

        return jsonify({
            "msg": "Livraison enregistrée avec succès", 
            "id": new_delivery.id,
            "total_amount": new_delivery.total_amount,
            "date": new_delivery.date.strftime("%Y-%m-%d %H:%M:%S"),
            "order_completed": bool(order_id)  
        }), 201

    except Exception as e:
        db.session.rollback()
        print(f"❌ ERREUR CRITIQUE LIVRAISON : {str(e)}") 
        return jsonify({"msg": f"Erreur interne : {str(e)}"}), 500


@delivery_bp.route('/', methods=['GET'])
@jwt_required()
def get_deliveries():
    claims = get_jwt()
    try:
        user_id = int(claims['sub'])
    except:
        user_id = claims['sub']
    
    user_type = claims.get('type')

    if user_type == 'admin':
        deliveries = Delivery.query.order_by(Delivery.date.desc()).all()
    else:
        deliveries = Delivery.query.filter_by(agent_id=user_id).order_by(Delivery.date.desc()).all()

    result = []
    for d in deliveries:
        
        items_summary = []
        q_vitale = 0
        q_voltic = 0
        
        for item in d.items:
            items_summary.append({
                "product_name": item.product.name,
                "quantity": item.quantity,
                "product_id": item.product_id
            })
            
            if 'Vitale' in item.product.name: q_vitale += item.quantity
            elif 'Voltic' in item.product.name: q_voltic += item.quantity

        result.append({
            "id": str(d.id),
            "created_at": d.date.strftime("%d/%m/%Y %H:%M"),
            "agent_name": d.agent.full_name if d.agent else "Inconnu",
            "agent_phone": d.agent.phone if d.agent else "--",
            "client_name": d.client.name if d.client else "Inconnu",
            "client_phone": d.client.phone if d.client else "--",
            "quantity_vitale": q_vitale, 
            "quantity_voltic": q_voltic, 
            "items": items_summary,      
            "total_amount": d.total_amount,
            "gps_lat": d.gps_lat_delivery,
            "gps_lng": d.gps_lng_delivery,
            "photo_url": format_url(d.photo_url),
            "signature_url": format_url(d.signature_url),
            "status": d.status,
            "date_iso": d.date.isoformat()  
        })
    return jsonify(result), 200


@delivery_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_delivery(id):
    d = Delivery.query.get_or_404(id)
    
    items_summary = []
    q_vitale = 0
    q_voltic = 0
    for item in d.items:
        items_summary.append({
            "product_name": item.product.name,
            "quantity": item.quantity,
            "product_id": item.product_id
        })
        if 'Vitale' in item.product.name: q_vitale += item.quantity
        elif 'Voltic' in item.product.name: q_voltic += item.quantity

    return jsonify({
        "id": str(d.id),
        "created_at": d.date.strftime("%d/%m/%Y %H:%M"),
        "agent_name": d.agent.full_name if d.agent else "Inconnu",
        "client_name": d.client.name if d.client else "Inconnu",
        "quantity_vitale": q_vitale,
        "quantity_voltic": q_voltic,
        "items": items_summary,
        "total_amount": d.total_amount,
        "status": d.status,
        "gps_lat": d.gps_lat_delivery,
        "gps_lng": d.gps_lng_delivery,
        "photo_url": format_url(d.photo_url),
        "signature_url": format_url(d.signature_url)
    }), 200


@delivery_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_delivery(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Accès interdit"}), 403

    delivery = Delivery.query.get_or_404(id)
    
    try:
        delivery_id = delivery.id
        delivery_info = {
            "client_name": delivery.client.name if delivery.client else "Inconnu",
            "agent_name": delivery.agent.full_name if delivery.agent else "Inconnu",
            "total_amount": delivery.total_amount
        }
        
        db.session.delete(delivery)
        db.session.commit()
        
        
        log_action(
            user_id=claims.get('sub'),
            action="DELETE_DELIVERY",
            entity_type="delivery",
            entity_id=delivery_id,
            details=delivery_info
        )
        
        return jsonify({"msg": "Livraison supprimée avec succès"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Erreur lors de la suppression"}), 500


@delivery_bp.route('/statuses', methods=['GET'])
@jwt_required()
def get_delivery_statuses():
    """Récupérer la liste des statuts possibles pour les livraisons"""
    return jsonify([
        {
            'value': 'pending',
            'label': 'En attente',
            'color': '#f59e0b',
            'description': 'Livraison en attente de validation'
        },
        {
            'value': 'in_progress',
            'label': 'En cours',
            'color': '#3b82f6',
            'description': 'Livraison en cours de traitement'
        },
        {
            'value': 'completed',
            'label': 'Terminée',
            'color': '#10b981',
            'description': 'Livraison terminée avec succès'
        },
        {
            'value': 'cancelled',
            'label': 'Annulée',
            'color': '#ef4444',
            'description': 'Livraison annulée'
        },
        {
            'value': 'failed',
            'label': 'Échouée',
            'color': '#6b7280',
            'description': 'Livraison échouée'
        }
    ]), 200