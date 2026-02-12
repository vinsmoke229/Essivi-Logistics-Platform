
import alembic.config
from alembic import command
from app import create_app

print("--- Starting migration script ---")


app_obj = create_app()

if isinstance(app_obj, tuple):
    app = app_obj[0]
else:
    app = app_obj


with app.app_context():
    print("App context created.")
    
    
    alembic_cfg = alembic.config.Config("migrations/alembic.ini")
    
    print("Alembic config loaded.")
    
    
    
    
    command.revision(alembic_cfg, 
                     message="feat: Add Evaluation, Product models and update Agent, Client models", 
                     autogenerate=True)
                     
    print("--- Migration script finished ---")
