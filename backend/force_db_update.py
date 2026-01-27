from app import create_app, db
from sqlalchemy import text
from app.models.sql_models import Product, DeliveryItem, OrderItem, StockItem # Assure que les modèles sont chargés

# Création de l'app
app_obj = create_app()
if isinstance(app_obj, tuple):
    app = app_obj[0]
else:
    app = app_obj

def force_update():
    print("🚀 Démarrage de la mise à jour forcée de la BDD...")
    
    with app.app_context():
        try:
            # 1. Création des nouvelles tables (delivery_items, order_items, etc.)
            print("📦 Création des tables manquantes via db.create_all()...")
            db.create_all()
            print("✅ Tables créées (si elles n'existaient pas).")

            # 2. Ajout manuel des colonnes si db.create_all n'a pas suffi (pour les tables existantes)
            # On vérifie/ajoute la colonne delivery_items s'il y a un doute, mais db.create_all le fait pour les nouvelles tables.
            # Pour les anciennes tables (deliveries), on veut peut-être SUPPRIMER les colonnes, mais on va d'abord migrer.
            
            conn = db.engine.connect()
            trans = conn.begin()
            
            try:
                # 3. Insertion des Produits de base (Verna !)
                print("🛒 Vérification des produits...")
                products_to_add = [
                    {'name': 'Vitale', 'price': 500.0},
                    {'name': 'Voltic', 'price': 300.0},
                    {'name': 'Verna', 'price': 400.0}
                ]
                
                for p_data in products_to_add:
                    conn.execute(text("""
                        INSERT INTO products (name, price, is_active) 
                        VALUES (:name, :price, true)
                        ON CONFLICT (name) DO NOTHING
                    """), p_data)
                    
                    # Création Stock initial si absent
                    conn.execute(text("""
                        INSERT INTO stock_items (product_id, location, total_stock, available_stock, reserved_stock, unit_price, unit, low_stock_threshold, last_restock_date, created_at, updated_at)
                        SELECT id, 'Entrepôt Principal', 1000, 1000, 0, :price, 'unités', 50, NOW(), NOW(), NOW()
                        FROM products WHERE name = :name
                        AND NOT EXISTS (SELECT 1 FROM stock_items WHERE product_id = products.id)
                    """), p_data)
                
                print("✅ Produits Vitale, Voltic et Verna assurés.")

                # 4. Migration des Données (Anciennes colonnes -> Nouvelle table)
                # On vérifie si la colonne quantity_vitale existe encore
                print("🔄 Migration des données (Vitale/Voltic)...")
                
                # Check column existence method (robust)
                result = conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name='deliveries' AND column_name='quantity_vitale'"))
                if result.scalar():
                    print("   ➜ Colonnes héritées détectées. Migration en cours...")
                    
                    # Migrer Livraisons -> DeliveryItems
                    conn.execute(text("""
                        INSERT INTO delivery_items (delivery_id, product_id, quantity)
                        SELECT d.id, p.id, d.quantity_vitale
                        FROM deliveries d
                        JOIN products p ON p.name = 'Vitale'
                        WHERE d.quantity_vitale > 0
                        AND NOT EXISTS (SELECT 1 FROM delivery_items di WHERE di.delivery_id = d.id AND di.product_id = p.id)
                    """))
                    
                    conn.execute(text("""
                        INSERT INTO delivery_items (delivery_id, product_id, quantity)
                        SELECT d.id, p.id, d.quantity_voltic
                        FROM deliveries d
                        JOIN products p ON p.name = 'Voltic'
                        WHERE d.quantity_voltic > 0
                        AND NOT EXISTS (SELECT 1 FROM delivery_items di WHERE di.delivery_id = d.id AND di.product_id = p.id)
                    """))
                    print("   ✅ Données Livraisons migrées.")
                    
                    # 5. Nettoyage des colonnes obsolètes (Optionnel, activé ici pour propreté)
                    print("🧹 Suppression des anciennes colonnes...")
                    conn.execute(text("ALTER TABLE deliveries DROP COLUMN IF EXISTS quantity_vitale"))
                    conn.execute(text("ALTER TABLE deliveries DROP COLUMN IF EXISTS quantity_voltic"))
                    conn.execute(text("ALTER TABLE deliveries DROP COLUMN IF EXISTS quantity_verna"))
                    
                    conn.execute(text("ALTER TABLE orders DROP COLUMN IF EXISTS quantity_vitale"))
                    conn.execute(text("ALTER TABLE orders DROP COLUMN IF EXISTS quantity_voltic"))
                    conn.execute(text("ALTER TABLE orders DROP COLUMN IF EXISTS quantity_verna"))
                    
                    print("   ✅ Colonnes supprimées.")
                else:
                    print("   ➜ Aucune migration nécessaire (colonnes déjà absentes).")

                # Validation
                trans.commit()
                print("🎉 SUCCÈS : Base de données à jour et propre !")
                
            except Exception as e:
                trans.rollback()
                print(f"❌ Erreur SQL Transaction : {e}")
                raise e
            finally:
                conn.close()

        except Exception as e:
            print(f"❌ Erreur Script : {e}")

if __name__ == "__main__":
    force_update()
