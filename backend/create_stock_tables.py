"""
Script pour créer les tables de stock manuellement
"""
from app import create_app, db
from app.models.sql_models import Product, StockItem, StockMovement, Agent, Client, VehicleStock
from datetime import datetime

def create_stock_tables():
    """Créer les tables de stock si elles n'existent pas"""
    app, _ = create_app()
    
    with app.app_context():
        print("🏗️ Création des tables de stock...")
        
        
        db.create_all()
        
        print("✅ Tables créées avec succès!")

if __name__ == "__main__":
    create_stock_tables()
