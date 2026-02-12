"""
Services Socket.IO pour les notifications temps réel
"""
from flask_socketio import emit, join_room, leave_room
from flask_jwt_extended import get_jwt, verify_jwt_in_request
from app import socketio
import logging

logger = logging.getLogger(__name__)


connected_users = {}

@socketio.on('connect')
def handle_connect():
    """Gérer la connexion d'un client"""
    try:
        
        
        try:
            verify_jwt_in_request()
            claims = get_jwt()
            user_id = claims.get('sub')
            user_type = claims.get('type', 'user')
        except:
            
            
            return True 
        
        if user_id:
            
            room = f"user_{user_id}"
            join_room(room)
            
            
            if user_type == 'admin':
                join_room('admin_room')
            elif user_type == 'agent':
                join_room('agents_room')
            
            
            connected_users[user_id] = {
                'sid': request.sid,
                'user_type': user_type,
                'connected_at': datetime.utcnow().isoformat()
            }
            
            logger.info(f"🔌 Utilisateur {user_id} ({user_type}) connecté")
            
            
            emit('connection_established', {
                'message': 'Connecté avec succès',
                'user_id': user_id,
                'user_type': user_type,
                'timestamp': datetime.utcnow().isoformat()
            })
    
    except Exception as e:
        
        if "Missing Authorization" not in str(e):
            logger.error(f"❌ Erreur socket connect: {str(e)}")

@socketio.on('disconnect')
def handle_disconnect():
    """Gérer la déconnexion d'un client"""
    try:
        
        user_id = None
        for uid, info in connected_users.items():
            if info.get('sid') == request.sid:
                user_id = uid
                break
        
        if user_id:
            user_info = connected_users[user_id]
            
            
            room = f"user_{user_id}"
            leave_room(room)
            
            if user_info['user_type'] == 'admin':
                leave_room('admin_room')
            elif user_info['user_type'] == 'agent':
                leave_room('agents_room')
            
            
            del connected_users[user_id]
            
            logger.info(f"🔌 Utilisateur {user_id} déconnecté")
            
            
            socketio.emit('user_disconnected', {
                'user_id': user_id,
                'user_type': user_info['user_type'],
                'timestamp': datetime.utcnow().isoformat()
            }, room='admin_room')
    
    except Exception as e:
        logger.error(f"❌ Erreur de déconnexion: {str(e)}")

@socketio.on('join_agent_room')
def handle_join_agent_room(data):
    """Permettre à un agent de rejoindre sa room spécifique"""
    try:
        verify_jwt_in_request()
        claims = get_jwt()
        user_id = claims.get('sub')
        
        if claims.get('type') == 'agent':
            agent_room = f"agent_{user_id}"
            join_room(agent_room)
            
            emit('room_joined', {
                'room': agent_room,
                'message': 'Room agent rejointe avec succès'
            })
            
            logger.info(f"🚚 Agent {user_id} a rejoint sa room")
    
    except Exception as e:
        logger.error(f"❌ Erreur join_agent_room: {str(e)}")
        emit('error', {'message': 'Erreur lors de la jointure de room'})


def emit_to_user(user_id, event, data):
    """Émettre un événement à un utilisateur spécifique"""
    room = f"user_{user_id}"
    socketio.emit(event, data, room=room)

def emit_to_admins(event, data):
    """Émettre un événement à tous les admins"""
    socketio.emit(event, data, room='admin_room')

def emit_to_agents(event, data):
    """Émettre un événement à tous les agents"""
    socketio.emit(event, data, room='agents_room')

def emit_to_all(event, data):
    """Émettre un événement à tous les utilisateurs connectés"""
    socketio.emit(event, data)


def notify_new_delivery(delivery_data):
    """Notifier les admins d'une nouvelle livraison"""
    emit_to_admins('new_delivery', {
        'delivery': delivery_data,
        'message': 'Nouvelle livraison enregistrée',
        'timestamp': datetime.utcnow().isoformat()
    })

def notify_agent_position_update(agent_id, position_data):
    """Notifier la mise à jour de position d'un agent"""
    emit_to_admins('agent_position_update', {
        'agent_id': agent_id,
        'position': position_data,
        'timestamp': datetime.utcnow().isoformat()
    })

def notify_low_stock(product_data):
    """Notifier tous les utilisateurs d'un stock bas"""
    emit_to_all('low_stock_alert', {
        'product': product_data,
        'message': f'⚠️ Stock bas pour {product_data.get("name", "Produit inconnu")}',
        'timestamp': datetime.utcnow().isoformat()
    })

def notify_delivery_status_update(delivery_id, new_status):
    """Notifier la mise à jour du statut d'une livraison"""
    emit_to_all('delivery_status_update', {
        'delivery_id': delivery_id,
        'new_status': new_status,
        'message': f'Statut de livraison mis à jour: {new_status}',
        'timestamp': datetime.utcnow().isoformat()
    })

def notify_new_order(order_data):
    """Notifier les admins d'une nouvelle commande"""
    emit_to_admins('new_order', {
        'order': order_data,
        'message': 'Nouvelle commande reçue',
        'timestamp': datetime.utcnow().isoformat()
    })

def notify_system_alert(alert_data):
    """Notifier une alerte système"""
    emit_to_admins('system_alert', {
        'alert': alert_data,
        'message': '🚨 Alerte système',
        'timestamp': datetime.utcnow().isoformat()
    })

def get_connected_users():
    """Retourner la liste des utilisateurs connectés"""
    return connected_users

from datetime import datetime
from flask import request
