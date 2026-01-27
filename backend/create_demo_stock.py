"""
Script pour créer des données de démonstration pour le stock ESSIVI
"""
from app import create_app, db
from app.models.sql_models import Product, StockItem, StockMovement, Agent, Client, VehicleStock
from datetime import datetime, timedelta
import random

def create_demo_stock_data():
    """Créer des données de démonstration pour le module de stock"""
    app, _ = create_app()
    
    with app.app_context():
        print("🏭 Création des données de démonstration pour le stock...")
        
        # Créer des produits
        products_data = [
            {"name": "Vitale 1.5L", "price": 250},
            {"name": "Voltic 1.5L", "price": 300},
            {"name": "Vitale 0.5L", "price": 150},
            {"name": "Voltic 0.5L", "price": 180},
            {"name": "Vitale 33cl", "price": 100},
            {"name": "Voltic 33cl", "price": 120}
        ]
        
        created_products = []
        for prod_data in products_data:
            product = Product.query.filter_by(name=prod_data["name"]).first()
            if not product:
                product = Product(
                    name=prod_data["name"],
                    price=prod_data["price"],
                    is_active=True
                )
                db.session.add(product)
                db.session.flush()
            created_products.append(product)
        
        # Créer des articles de stock
        stock_items_data = [
            {"product": "Vitale 1.5L", "total_stock": 500, "available_stock": 450, "threshold": 50},
            {"product": "Voltic 1.5L", "total_stock": 300, "available_stock": 280, "threshold": 30},
            {"product": "Vitale 0.5L", "total_stock": 200, "available_stock": 180, "threshold": 25},
            {"product": "Voltic 0.5L", "total_stock": 150, "available_stock": 140, "threshold": 20},
            {"product": "Vitale 33cl", "total_stock": 100, "available_stock": 95, "threshold": 15},
            {"product": "Voltic 33cl", "total_stock": 80, "available_stock": 75, "threshold": 10}
        ]
        
        created_stock_items = []
        for stock_data in stock_items_data:
            product = next(p for p in created_products if p.name == stock_data["product"])
            
            stock_item = StockItem.query.filter_by(product_id=product.id).first()
            if not stock_item:
                stock_item = StockItem(
                    product_id=product.id,
                    location="Entrepôt Principal",
                    total_stock=stock_data["total_stock"],
                    available_stock=stock_data["available_stock"],
                    reserved_stock=stock_data["total_stock"] - stock_data["available_stock"],
                    unit_price=product.price,
                    unit="bouteilles",
                    low_stock_threshold=stock_data["threshold"],
                    last_restock_date=datetime.now() - timedelta(days=random.randint(1, 30))
                )
                db.session.add(stock_item)
                db.session.flush()
            created_stock_items.append(stock_item)
        
        # Créer des mouvements de stock récents
        movement_types = ["in", "out"]
        references = ["RESTOCK", "VENTE", "RETOUR", "PERTE", "TRANSFERT"]
        agents = Agent.query.limit(5).all()
        clients = Client.query.limit(10).all()
        
        for _ in range(50):
            stock_item = random.choice(created_stock_items)
            movement = StockMovement(
                stock_item_id=stock_item.id,
                movement_type=random.choice(movement_types),
                quantity=random.randint(1, 50),
                reference=random.choice(references),
                agent_id=random.choice(agents).id if agents else None,
                client_id=random.choice(clients).id if clients else None,
                notes=f"Mouvement de démonstration",
                timestamp=datetime.now() - timedelta(hours=random.randint(1, 168))
            )
            db.session.add(movement)
        
        # Créer des stocks de véhicules
        if agents:
            for agent in agents[:3]:  # 3 premiers agents
                for product in created_products[:3]:  # 3 premiers produits
                    vehicle_stock = VehicleStock.query.filter_by(
                        agent_id=agent.id, 
                        product_id=product.id
                    ).first()
                    
                    if not vehicle_stock:
                        vehicle_stock = VehicleStock(
                            agent_id=agent.id,
                            product_id=product.id,
                            current_stock=random.randint(10, 50),
                            max_capacity=100,
                            status="loading",
                            last_updated=datetime.now()
                        )
                        db.session.add(vehicle_stock)
        
        db.session.commit()
        print("✅ Données de démonstration créées avec succès!")
        print(f"📦 {len(created_products)} produits créés")
        print(f"📋 {len(created_stock_items)} articles de stock créés")
        print(f"📊 50 mouvements de stock créés")
        print("🚚 Stocks de véhicules créés")

if __name__ == "__main__":
    create_demo_stock_data()
