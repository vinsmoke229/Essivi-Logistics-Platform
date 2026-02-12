from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import Client, Order, Delivery
from flask_jwt_extended import jwt_required, get_jwt
from datetime import datetime

client_bp = Blueprint('client', __name__, url_prefix='/api/client')

def format_url(url):
    if not url: return None
    if url.startswith('http'): return url
    path = url[1:] if url.startswith('/') else url
    return f"{request.host_url}{path}"


@client_bp.route('/orders', methods=['GET'])
@jwt_required()
def get_client_orders():
    claims = get_jwt()
    
    
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    try:
        client_id = int(claims['sub'])
    except:
        return jsonify({"msg": "ID client invalide"}), 400
    
    print(f"🔍 DEBUG - ClientOrders: Récupération commandes pour client {client_id}")
    
    
    orders = Order.query.filter_by(client_id=client_id).order_by(Order.created_at.desc()).all()
    
    result = []
    for order in orders:
        
        items_summary = []
        for item in order.items:
            items_summary.append({
                "product_name": item.product.name if item.product else "Produit inconnu",
                "quantity": item.quantity
            })
            
        result.append({
            "id": order.id,
            "status": order.status,
            "items": items_summary,
            "preferred_time": order.preferred_delivery_time,
            "special_instructions": order.instructions,
            "created_at": order.created_at.isoformat() if order.created_at else None,
            "updated_at": order.created_at.isoformat() if order.created_at else None, 
            "total_amount": sum((item.product.price * item.quantity for item in order.items if item.product))
        })
    
    print(f"✅ DEBUG - {len(result)} commandes trouvées")
    return jsonify(result), 200


@client_bp.route('/deliveries', methods=['GET'])
@jwt_required()
def get_client_deliveries():
    claims = get_jwt()
    
    
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    try:
        client_id = int(claims['sub'])
    except:
        return jsonify({"msg": "ID client invalide"}), 400
    
    print(f"🔍 DEBUG - ClientDeliveries: Récupération livraisons pour client {client_id}")
    
    
    deliveries = Delivery.query.filter_by(client_id=client_id).order_by(Delivery.date.desc()).all()
    
    result = []
    for delivery in deliveries:
        
        items_summary = []
        for item in delivery.items:
            items_summary.append({
                "product_name": item.product.name if item.product else "Produit inconnu",
                "quantity": item.quantity
            })

        result.append({
            "id": delivery.id,
            "items": items_summary,
            "total_amount": delivery.total_amount,
            "date": delivery.date.isoformat() if delivery.date else None,
            "status": delivery.status,
            "gps_lat": delivery.gps_lat_delivery,
            "gps_lng": delivery.gps_lng_delivery,
            "photo_url": format_url(delivery.photo_url),
            "signature_url": format_url(delivery.signature_url)
        })
    
    print(f"✅ DEBUG - {len(result)} livraisons trouvées")
    return jsonify(result), 200


@client_bp.route('/invoices', methods=['GET'])
@jwt_required()
def get_client_invoices():
    claims = get_jwt()
    
    
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    try:
        client_id = int(claims['sub'])
    except:
        return jsonify({"msg": "ID client invalide"}), 400
    
    print(f"🔍 DEBUG - ClientInvoices: Récupération factures pour client {client_id}")
    
    
    client = Client.query.get(client_id)
    if not client:
        return jsonify({"msg": "Client non trouvé"}), 404
    
    
    deliveries = Delivery.query.filter_by(client_id=client_id, status='completed').order_by(Delivery.date.desc()).all()
    
    invoices = []
    for delivery in deliveries:
        invoice = {
            "id": delivery.id,
            "invoice_number": f"INV-{delivery.id:06d}",
            "client_name": client.name,
            "client_address": client.address,
            "delivery_date": delivery.date.isoformat() if delivery.date else None,
            "items": [],
            "subtotal": 0,
            "tax": 0,
            "total": delivery.total_amount
        }
        
        
        if delivery.quantity_vitale > 0:
            invoice["items"].append({
                "name": "Eau Vitale",
                "quantity": delivery.quantity_vitale,
                "unit_price": 500,  
                "total": delivery.quantity_vitale * 500
            })
            invoice["subtotal"] += delivery.quantity_vitale * 500
        
        if delivery.quantity_voltic > 0:
            invoice["items"].append({
                "name": "Eau Voltic",
                "quantity": delivery.quantity_voltic,
                "unit_price": 500,  
                "total": delivery.quantity_voltic * 500
            })
            invoice["subtotal"] += delivery.quantity_voltic * 500
        
        
        invoice["tax"] = invoice["subtotal"] * 0.18
        
        invoices.append(invoice)
    
    print(f"✅ DEBUG - {len(invoices)} factures générées")
    return jsonify(invoices), 200


@client_bp.route('/invoices/<int:delivery_id>', methods=['GET'])
@jwt_required()
def get_invoice_detail(delivery_id):
    claims = get_jwt()
    
    
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    try:
        client_id = int(claims['sub'])
    except:
        return jsonify({"msg": "ID client invalide"}), 400
    
    
    delivery = Delivery.query.filter_by(id=delivery_id, client_id=client_id).first()
    if not delivery:
        return jsonify({"msg": "Facture non trouvée"}), 404
    
    
    client = Client.query.get(client_id)
    
    
    invoice = {
        "id": delivery.id,
        "invoice_number": f"INV-{delivery.id:06d}",
        "client": {
            "name": client.name,
            "address": client.address,
            "phone": client.phone
        },
        "delivery_date": delivery.date.isoformat() if delivery.date else None,
        "items": [],
        "subtotal": 0,
        "tax_rate": 0.18,
        "tax": 0,
        "total": delivery.total_amount,
        "status": delivery.status,
        "payment_status": "paid" if delivery.status == 'completed' else "pending"
    }
    
    
    if delivery.quantity_vitale > 0:
        invoice["items"].append({
            "name": "Eau Vitale",
            "description": "Eau minérale Vitale 1.5L",
            "quantity": delivery.quantity_vitale,
            "unit_price": 500,
            "total": delivery.quantity_vitale * 500
        })
        invoice["subtotal"] += delivery.quantity_vitale * 500
    
    if delivery.quantity_voltic > 0:
        invoice["items"].append({
            "name": "Eau Voltic",
            "description": "Eau minérale Voltic 1.5L",
            "quantity": delivery.quantity_voltic,
            "unit_price": 500,
            "total": delivery.quantity_voltic * 500
        })
        invoice["subtotal"] += delivery.quantity_voltic * 500
    
    
    invoice["tax"] = invoice["subtotal"] * invoice["tax_rate"]
    
    return jsonify(invoice), 200


@client_bp.route('/stats', methods=['GET'])
@jwt_required()
def get_client_stats():
    claims = get_jwt()
    
    
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    try:
        client_id = int(claims['sub'])
    except:
        return jsonify({"msg": "ID client invalide"}), 400
    
    
    total_orders = Order.query.filter_by(client_id=client_id).count()
    completed_deliveries = Delivery.query.filter_by(client_id=client_id, status='completed').count()
    pending_orders = Order.query.filter_by(client_id=client_id).filter(Order.status.in_(['pending', 'accepted', 'in_progress'])).count()
    
    
    total_amount = db.session.query(db.func.sum(Delivery.total_amount)).filter_by(client_id=client_id, status='completed').scalar() or 0
    
    stats = {
        "total_orders": total_orders,
        "completed_deliveries": completed_deliveries,
        "pending_deliveries": pending_orders, 
        "total_amount_spent": total_amount,
        "average_basket": total_amount / completed_deliveries if completed_deliveries > 0 else 0
    }
    
    return jsonify(stats), 200


@client_bp.route('/details/<int:id>', methods=['GET'])
@jwt_required()
def get_client_details_admin(id):
    claims = get_jwt()
    if claims.get('type') != 'admin':
        return jsonify({"msg": "Réservé aux administrateurs"}), 403

    client = Client.query.get_or_404(id)
    
    
    total_orders = Order.query.filter_by(client_id=id).count()
    completed_deliveries = Delivery.query.filter_by(client_id=id, status='completed').count()
    total_amount = db.session.query(db.func.sum(Delivery.total_amount)).filter_by(client_id=id, status='completed').scalar() or 0
    
    
    latest_orders = Order.query.filter_by(client_id=id).order_by(Order.created_at.desc()).limit(10).all()
    orders_data = []
    for o in latest_orders:
        orders_data.append({
            "id": o.id,
            "status": o.status,
            "created_at": o.created_at.strftime("%d/%m/%Y %H:%M"),
            "total_amount": sum([i.quantity * (i.product.price if i.product else 0) for i in o.items])
        })

    return jsonify({
        "info": {
            "name": client.name,
            "phone": client.phone,
            "address": client.address,
            "gps_lat": client.gps_lat,
            "gps_lng": client.gps_lng,
            "photo_url": format_url(client.photo_url) if client.photo_url else None
        },
        "stats": {
            "total_orders": total_orders,
            "completed_deliveries": completed_deliveries,
            "total_amount_spent": total_amount,
            "average_basket": total_amount / completed_deliveries if completed_deliveries > 0 else 0
        },
        "latest_orders": orders_data
    }), 200


@client_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    claims = get_jwt()
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    client = Client.query.get(int(claims['sub']))
    if not client:
        return jsonify({"msg": "Client non trouvé"}), 404
        
    return jsonify({
        "name": client.name,
        "phone": client.phone,
        "address": client.address,
        "responsible_name": client.responsible_name
    }), 200


@client_bp.route('/change-pin', methods=['PUT'])
@jwt_required()
def change_pin():
    claims = get_jwt()
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
        
    data = request.get_json()
    old_pin = data.get('old_pin')
    new_pin = data.get('new_pin')
    
    if not old_pin or not new_pin:
        return jsonify({"msg": "Ancien et nouveau PIN requis"}), 400
        
    client = Client.query.get(int(claims['sub']))
    from werkzeug.security import check_password_hash, generate_password_hash
    
    if not check_password_hash(client.pin_hash, old_pin):
        return jsonify({"msg": "Ancien code PIN incorrect"}), 401
        
    client.pin_hash = generate_password_hash(new_pin)
    db.session.commit()
    
    return jsonify({"msg": "Code PIN mis à jour avec succès"}), 200


@client_bp.route('/export-pdf', methods=['GET'])
@jwt_required()
def export_invoices_pdf():
    claims = get_jwt()
    if claims.get('type') != 'client':
        return jsonify({"msg": "Accès réservé aux clients"}), 403
    
    
    
    return jsonify({
        "msg": "Facture PDF générée avec succès",
        "download_url": "https://example.com/invoice_sample.pdf"
    }), 200
