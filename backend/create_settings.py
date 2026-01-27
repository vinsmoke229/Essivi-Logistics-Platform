"""
Script pour créer les paramètres système par défaut
"""
from app import create_app, db
from app.models.sql_models import SystemSettings

def create_default_settings():
    """Créer les paramètres système par défaut"""
    app, _ = create_app()
    
    with app.app_context():
        print("⚙️ Création des paramètres système par défaut...")
        
        default_settings = {
            'platform_name': 'ESSIVI Delivery Management',
            'currency': 'FCFA',
            'timezone': 'GMT+0',
            'company_name': 'ESSIVI SARL',
            'company_address': 'Lomé, Togo',
            'company_phone': '+228 22 00 00 00',
            'company_email': 'contact@essivi.tg',
            'tax_rate': 18,
            'low_stock_threshold': 10,
            'auto_backup': True,
            'notification_email': True,
            'notification_sms': False,
            'max_delivery_distance': 50,
            'default_delivery_fee': 500,
            'working_hours_start': '08:00',
            'working_hours_end': '18:00'
        }
        
        for key, value in default_settings.items():
            setting = SystemSettings.query.filter_by(key=key).first()
            if not setting:
                setting = SystemSettings(
                    key=key,
                    value=str(value),
                    description=f"Paramètre {key}"
                )
                db.session.add(setting)
        
        db.session.commit()
        print("✅ Paramètres système créés avec succès!")
        print(f"📋 {len(default_settings)} paramètres configurés")

if __name__ == "__main__":
    create_default_settings()
