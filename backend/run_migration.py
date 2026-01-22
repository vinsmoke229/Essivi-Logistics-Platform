# run_migration.py
import alembic.config
from alembic import command
from app import create_app

print("--- Starting migration script ---")

# Create a Flask app instance to establish context
app = create_app()

# The app context is needed for SQLAlchemy to know about the models
with app.app_context():
    print("App context created.")
    
    # Get the Alembic config object
    alembic_cfg = alembic.config.Config("migrations/alembic.ini")
    
    print("Alembic config loaded.")
    
    # Programmatically call the 'revision' command
    # --autogenerate tells Alembic to compare models with the DB state
    # -m is the message
    command.revision(alembic_cfg, 
                     message="feat: Add Evaluation, Product models and update Agent, Client models", 
                     autogenerate=True)
                     
    print("--- Migration script finished ---")
