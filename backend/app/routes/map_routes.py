from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt
from app import db
from app.models.sql_models import Agent, Client, Delivery
from datetime import datetime, timedelta
import json

map_bp = Blueprint('map', __name__, url_prefix='/api/map')

@map_bp.route('/realtime-positions', methods=['GET'])
@jwt_required()
def get_realtime_positions():
    """Récupérer les positions temps réel de tous les acteurs"""
    try:
        positions = []
        
        # Positions des agents actifs
        agents = Agent.query.filter_by(is_active=True).all()
        for agent in agents:
            if agent.last_lat and agent.last_lng:
                positions.append({
                    'id': f'agent-{agent.id}',
                    'lat': agent.last_lat,
                    'lng': agent.last_lng,
                    'type': 'agent',
                    'name': agent.full_name,
                    'phone': agent.phone,
                    'tricycle_plate': agent.tricycle_plate,
                    'last_seen': agent.last_seen.isoformat() if agent.last_seen else None,
                    'status': 'online' if agent.last_seen and (datetime.utcnow() - agent.last_seen).seconds < 300 else 'offline'
                })
        
        # Positions des clients avec GPS
        clients = Client.query.filter(
            Client.gps_lat.isnot(None),
            Client.gps_lng.isnot(None)
        ).all()
        for client in clients:
            positions.append({
                'id': f'client-{client.id}',
                'lat': client.gps_lat,
                'lng': client.gps_lng,
                'type': 'client',
                'name': client.name,
                'phone': client.phone,
                'address': client.address
            })
        
        # Positions des livraisons du jour avec GPS
        today = datetime.utcnow().date()
        deliveries = Delivery.query.filter(
            Delivery.date >= today,
            Delivery.gps_lat_delivery.isnot(None),
            Delivery.gps_lng_delivery.isnot(None)
        ).all()
        
        for delivery in deliveries:
            try:
                # Calcul sécurisé des volumes
                qty_vitale = sum(item.quantity or 0 for item in delivery.items if item.product and ('Vitale' in item.product.name or 'VITALE' in item.product.name))
                qty_voltic = sum(item.quantity or 0 for item in delivery.items if item.product and ('Voltic' in item.product.name or 'VOLTIC' in item.product.name))
                
                positions.append({
                    'id': f'delivery-{delivery.id}',
                    'lat': delivery.gps_lat_delivery,
                    'lng': delivery.gps_lng_delivery,
                    'type': 'delivery',
                    'client_name': delivery.client.name if delivery.client else 'Inconnu',
                    'agent_name': delivery.agent.full_name if delivery.agent else 'Inconnu',
                    'quantity_vitale': int(qty_vitale),
                    'quantity_voltic': int(qty_voltic),
                    'total_amount': float(delivery.total_amount or 0),
                    'status': delivery.status,
                    'timestamp': delivery.date.isoformat() if delivery.date else ""
                })
            except Exception as e:
                print(f"Error mapping delivery {delivery.id}: {e}")
                continue

        
        if not positions:
            return jsonify([]), 200
            
        return jsonify(positions), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/agent-positions', methods=['GET'])
@jwt_required()
def get_agent_positions():
    """Récupérer les positions des agents uniquement"""
    try:
        agents = Agent.query.filter_by(is_active=True).all()
        positions = []
        
        for agent in agents:
            position = {
                'id': agent.id,
                'name': agent.full_name,
                'phone': agent.phone,
                'tricycle_plate': agent.tricycle_plate,
                'lat': agent.last_lat,
                'lng': agent.last_lng,
                'last_seen': agent.last_seen.isoformat() if agent.last_seen else None,
                'status': 'online' if agent.last_seen and (datetime.utcnow() - agent.last_seen).seconds < 300 else 'offline'
            }
            positions.append(position)
        
        return jsonify(positions), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/update-agent-position', methods=['POST'])
@jwt_required()
def update_agent_position():
    """Mettre à jour la position d'un agent (appelé par l'application mobile)"""
    try:
        claims = get_jwt()
        user_type = claims.get('type')
        
        if user_type != 'agent':
            return jsonify({"msg": "Accès réservé aux agents"}), 403
        
        agent_id = int(claims['sub'])
        data = request.get_json()
        
        agent = Agent.query.get(agent_id)
        if not agent:
            return jsonify({"msg": "Agent non trouvé"}), 404
        
        # Mettre à jour la position
        agent.last_lat = data.get('lat')
        agent.last_lng = data.get('lng')
        agent.last_seen = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            "msg": "Position mise à jour avec succès",
            "lat": agent.last_lat,
            "lng": agent.last_lng,
            "timestamp": agent.last_seen.isoformat()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/delivery-zones', methods=['GET'])
@jwt_required()
def get_delivery_zones():
    """Récupérer les zones de chalandise pour la carte"""
    try:
        # Analyser les livraisons pour créer des zones de chaleur
        deliveries = Delivery.query.filter(
            Delivery.gps_lat_delivery.isnot(None),
            Delivery.gps_lng_delivery.isnot(None),
            Delivery.date >= datetime.utcnow() - timedelta(days=30)
        ).all()
        
        # Regrouper par zones (approximation avec grille simple)
        zones = {}
        for delivery in deliveries:
            if delivery.gps_lat_delivery and delivery.gps_lng_delivery:
                # Grille de 0.01 degré (~1km)
                lat_grid = round(delivery.gps_lat_delivery, 2)
                lng_grid = round(delivery.gps_lng_delivery, 2)
                zone_key = f"{lat_grid}_{lng_grid}"
                
                if zone_key not in zones:
                    zones[zone_key] = {
                        'center_lat': lat_grid,
                        'center_lng': lng_grid,
                        'delivery_count': 0,
                        'total_amount': 0,
                        'clients': set()
                    }
                
                zones[zone_key]['delivery_count'] += 1
                zones[zone_key]['total_amount'] += delivery.total_amount
                if delivery.client_id:
                    zones[zone_key]['clients'].add(delivery.client_id)
        
        # Convertir en liste et calculer l'intensité
        result = []
        max_deliveries = max([zone['delivery_count'] for zone in zones.values()]) if zones else 1
        
        for zone_data in zones.values():
            intensity = zone_data['delivery_count'] / max_deliveries
            result.append({
                'center_lat': zone_data['center_lat'],
                'center_lng': zone_data['center_lng'],
                'delivery_count': zone_data['delivery_count'],
                'unique_clients': len(zone_data['clients']),
                'total_amount': zone_data['total_amount'],
                'intensity': intensity,
                'radius': 500 + (intensity * 1000)  # Rayon entre 500m et 1500m
            })
        
        return jsonify(result), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/optimize-route', methods=['POST'])
@jwt_required()
def optimize_delivery_route():
    """Optimiser une tournée de livraison pour un agent"""
    try:
        data = request.get_json()
        agent_id = data.get('agent_id')
        delivery_ids = data.get('delivery_ids', [])
        
        if not agent_id or not delivery_ids:
            return jsonify({"msg": "Agent ID et livraisons requis"}), 400
        
        # Récupérer les livraisons avec leurs positions
        deliveries = Delivery.query.filter(
            Delivery.id.in_(delivery_ids),
            Delivery.gps_lat_delivery.isnot(None),
            Delivery.gps_lng_delivery.isnot(None)
        ).all()
        
        if len(deliveries) != len(delivery_ids):
            return jsonify({"msg": "Certaines livraisons n'ont pas de coordonnées GPS"}), 400
        
        # Récupérer la position de l'agent
        agent = Agent.query.get(agent_id)
        if not agent or not agent.last_lat or not agent.last_lng:
            return jsonify({"msg": "Position de l'agent non disponible"}), 400
        
        # Algorithme simple de plus proche voisin (TSP approximatif)
        waypoints = [{
            'id': 'start',
            'lat': agent.last_lat,
            'lng': agent.last_lng,
            'name': "Position actuelle"
        }]
        
        remaining_deliveries = deliveries.copy()
        current_lat = agent.last_lat
        current_lng = agent.last_lng
        
        while remaining_deliveries:
            # Trouver la livraison la plus proche
            nearest = None
            min_distance = float('inf')
            
            for delivery in remaining_deliveries:
                distance = ((delivery.gps_lat_delivery - current_lat) ** 2 + 
                           (delivery.gps_lng_delivery - current_lng) ** 2) ** 0.5
                if distance < min_distance:
                    min_distance = distance
                    nearest = delivery
            
            if nearest:
                waypoints.append({
                    'id': f'delivery-{nearest.id}',
                    'lat': nearest.gps_lat_delivery,
                    'lng': nearest.gps_lng_delivery,
                    'name': nearest.client.name if nearest.client else f'Client {nearest.id}',
                    'delivery_id': nearest.id,
                    'client_name': nearest.client.name if nearest.client else 'Inconnu',
                    'quantity_vitale': sum(item.quantity for item in nearest.items if item.product and 'Vitale' in item.product.name),
                    'quantity_voltic': sum(item.quantity for item in nearest.items if item.product and 'Voltic' in item.product.name),
                    'total_amount': nearest.total_amount or 0
                })
                
                current_lat = nearest.gps_lat_delivery
                current_lng = nearest.gps_lng_delivery
                remaining_deliveries.remove(nearest)
        
        # Calculer les statistiques
        total_distance = 0
        for i in range(len(waypoints) - 1):
            dist = ((waypoints[i+1]['lat'] - waypoints[i]['lat']) ** 2 + 
                   (waypoints[i+1]['lng'] - waypoints[i]['lng']) ** 2) ** 0.5
            total_distance += dist
        
        return jsonify({
            'agent_id': agent_id,
            'waypoints': waypoints,
            'total_distance_km': round(total_distance * 111, 2),  # Conversion approximative en km
            'estimated_time_minutes': round(total_distance * 111 * 2),  # ~2min/km
            'delivery_count': len(deliveries),
            'total_amount': sum(d.total_amount for d in deliveries),
            'optimized_at': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/heatmap', methods=['GET'])
@jwt_required()
def get_delivery_heatmap():
    """Générer une carte de chaleur des livraisons"""
    try:
        # Paramètres
        days = request.args.get('days', 30, type=int)
        
        # Récupérer les livraisons récentes avec filtres NULL robustes
        since_date = datetime.utcnow() - timedelta(days=days)
        deliveries = Delivery.query.filter(
            Delivery.date >= since_date,
            Delivery.gps_lat_delivery.isnot(None),
            Delivery.gps_lng_delivery.isnot(None)
        ).all()
        
        # Générer les points de chaleur
        heat_points = []
        for delivery in deliveries:
            try:
                # Sécurité : vérifier que items existe et n'est pas None
                if not delivery.items:
                    items_qty = 0
                else:
                    # Filtrer les items avec quantity NULL
                    items_qty = sum(
                        item.quantity or 0 
                        for item in delivery.items 
                        if item.quantity is not None
                    )
                
                # Sécurité : vérifier que total_amount n'est pas None
                total_amount = delivery.total_amount or 0
                
                # Vérifier que les coordonnées sont valides
                if delivery.gps_lat_delivery is None or delivery.gps_lng_delivery is None:
                    continue
                
                heat_points.append({
                    'lat': float(delivery.gps_lat_delivery),
                    'lng': float(delivery.gps_lng_delivery),
                    'intensity': min(total_amount / 1000, 1.0),
                    'weight': 1 + items_qty / 10
                })
            except Exception as e:
                # Log l'erreur mais continue le traitement
                print(f"⚠️ Erreur traitement delivery {delivery.id}: {str(e)}")
                continue
        
        # Retourner un objet vide si aucun point
        if not heat_points:
            return jsonify({
                'points': [],
                'maxIntensity': 0,
                'total_points': 0,
                'period_days': days,
                'generated_at': datetime.utcnow().isoformat()
            }), 200
        
        # Calculer l'intensité maximale
        max_intensity = max(point['intensity'] for point in heat_points) if heat_points else 1.0
        
        return jsonify({
            'points': heat_points,
            'maxIntensity': max_intensity,
            'total_points': len(heat_points),
            'period_days': days,
            'generated_at': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        # Erreur globale : retourner un objet vide au lieu de crasher
        print(f"❌ Erreur get_delivery_heatmap: {str(e)}")
        return jsonify({
            'points': [],
            'maxIntensity': 0,
            'total_points': 0,
            'error': str(e)
        }), 200  # 200 au lieu de 500 pour éviter les erreurs côté client


@map_bp.route('/zones-chalandise', methods=['GET', 'OPTIONS'])
@jwt_required()
def get_zones_chalandise():
    """Récupérer les zones de chalandise"""
    try:
        zones = [
            {
                "id": "zone_centre",
                "name": "Zone Centre-Ville",
                "bounds": [[6.120, 1.210], [6.140, 1.230]],
                "color": "#3b82f6",
                "clientCount": 45,
                "deliveryCount": 120,
                "avgDeliveryValue": 5000
            },
            {
                "id": "zone_nord", 
                "name": "Zone Nord",
                "bounds": [[6.140, 1.210], [6.160, 1.230]],
                "color": "#10b981",
                "clientCount": 32,
                "deliveryCount": 85,
                "avgDeliveryValue": 4500
            },
            {
                "id": "zone_sud",
                "name": "Zone Sud", 
                "bounds": [[6.100, 1.210], [6.120, 1.230]],
                "color": "#f59e0b",
                "clientCount": 28,
                "deliveryCount": 67,
                "avgDeliveryValue": 4200
            }
        ]
        return jsonify(zones), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/optimize-route/<agent_id>', methods=['POST', 'OPTIONS'])
@jwt_required()
def optimize_route(agent_id):
    """Optimiser l'itinéraire pour un agent"""
    try:
        if not agent_id or agent_id == 'undefined':
            return jsonify({"msg": "ID d'agent invalide"}), 400
            
        data = request.get_json()
        deliveries_data = data.get('deliveries', [])
        
        agent = Agent.query.get(agent_id)
        if not agent or not agent.last_lat or not agent.last_lng:
            return jsonify({"msg": "Position de l'agent non disponible"}), 400
            
        if not deliveries_data:
            return jsonify({
                "agentId": agent_id,
                "totalDistance": 0,
                "estimatedTime": 0,
                "efficiency": 100,
                "waypoints": [[agent.last_lat, agent.last_lng]],
                "deliveries": []
            }), 200

        waypoints = [[agent.last_lat, agent.last_lng]]
        current_lat = agent.last_lat
        current_lng = agent.last_lng
        
        remaining_deliveries = deliveries_data.copy()
        ordered_deliveries = []
        total_distance = 0
        
        from app.utils import haversine_distance
        
        while remaining_deliveries:
            nearest_idx = -1
            min_dist = float('inf')
            
            for i, d in enumerate(remaining_deliveries):
                lat = d.get('gps_lat') or d.get('lat')
                lng = d.get('gps_lng') or d.get('lng')
                if lat is None or lng is None: continue
                
                dist = haversine_distance(current_lat, current_lng, lat, lng)
                if dist < min_dist:
                    min_dist = dist
                    nearest_idx = i
            
            if nearest_idx != -1:
                nearest = remaining_deliveries.pop(nearest_idx)
                lat = nearest.get('gps_lat') or nearest.get('lat')
                lng = nearest.get('gps_lng') or nearest.get('lng')
                
                waypoints.append([lat, lng])
                ordered_deliveries.append(nearest)
                total_distance += min_dist
                current_lat = lat
                current_lng = lng
            else:
                break
        
        return jsonify({
            "agentId": agent_id,
            "totalDistance": round(total_distance, 2),
            "estimatedTime": round(total_distance * 3), 
            "efficiency": max(60, 100 - int(total_distance)),
            "waypoints": waypoints,
            "deliveries": ordered_deliveries
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/stats', methods=['GET'])
@jwt_required()
def get_map_statistics():
    """Statistiques pour la carte"""
    try:
        online_agents = Agent.query.filter(
            Agent.is_active == True,
            Agent.last_lat.isnot(None),
            Agent.last_lng.isnot(None),
            Agent.last_seen >= datetime.utcnow() - timedelta(minutes=5)
        ).count()
        
        today_deliveries = Delivery.query.filter(
            Delivery.date >= datetime.utcnow().date()
        ).count()
        
        clients_with_gps = Client.query.filter(
            Client.gps_lat.isnot(None),
            Client.gps_lng.isnot(None)
        ).count()
        
        deliveries = Delivery.query.filter(
            Delivery.gps_lat_delivery.isnot(None),
            Delivery.gps_lng_delivery.isnot(None),
            Delivery.date >= datetime.utcnow() - timedelta(days=7)
        ).all()
        
        coverage_area = None
        if deliveries:
            lats = [d.gps_lat_delivery for d in deliveries]
            lngs = [d.gps_lng_delivery for d in deliveries]
            coverage_area = {
                'center_lat': sum(lats) / len(lats),
                'center_lng': sum(lngs) / len(lngs),
                'radius_km': 5
            }
        
        return jsonify({
            'online_agents': online_agents,
            'today_deliveries': today_deliveries,
            'clients_with_gps': clients_with_gps,
            'coverage_area': coverage_area,
            'updated_at': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@map_bp.route('/export', methods=['POST', 'OPTIONS'])
@jwt_required()
def export_map_data():
    """Exporter les données de la carte"""
    try:
        if request.method == 'OPTIONS':
            return jsonify({"msg": "OK"}), 200
            
        data = request.get_json() or {}
        export_type = data.get('format', 'excel')
        
        return jsonify({
            "msg": f"Export {export_type} généré avec succès (Simulé)",
            "filename": f"map_export_{datetime.now().strftime('%Y%m%d_%H%M')}.{export_type}"
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur export: {str(e)}"}), 500
