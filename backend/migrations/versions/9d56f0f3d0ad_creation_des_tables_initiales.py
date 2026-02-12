"""Creation des tables initiales

Revision ID: 9d56f0f3d0ad
Revises: 
Create Date: 2025-12-30 15:01:45.706163

"""
from alembic import op
import sqlalchemy as sa



revision = '9d56f0f3d0ad'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    
    op.create_table('agents',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('matricule', sa.String(length=20), nullable=False),
    sa.Column('full_name', sa.String(length=100), nullable=False),
    sa.Column('phone', sa.String(length=20), nullable=False),
    sa.Column('password_hash', sa.String(length=256), nullable=False),
    sa.Column('tricycle_plate', sa.String(length=20), nullable=True),
    sa.Column('is_active', sa.Boolean(), nullable=True),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('matricule'),
    sa.UniqueConstraint('phone')
    )
    op.create_table('clients',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('name', sa.String(length=100), nullable=False),
    sa.Column('responsible_name', sa.String(length=100), nullable=True),
    sa.Column('phone', sa.String(length=20), nullable=False),
    sa.Column('address', sa.String(length=200), nullable=True),
    sa.Column('gps_lat', sa.Float(), nullable=True),
    sa.Column('gps_lng', sa.Float(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('phone')
    )
    op.create_table('users',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('username', sa.String(length=50), nullable=False),
    sa.Column('email', sa.String(length=120), nullable=False),
    sa.Column('password_hash', sa.String(length=256), nullable=False),
    sa.Column('role', sa.String(length=20), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('email'),
    sa.UniqueConstraint('username')
    )
    op.create_table('deliveries',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('date', sa.DateTime(), nullable=True),
    sa.Column('agent_id', sa.Integer(), nullable=False),
    sa.Column('client_id', sa.Integer(), nullable=False),
    sa.Column('quantity_vitale', sa.Integer(), nullable=True),
    sa.Column('quantity_voltic', sa.Integer(), nullable=True),
    sa.Column('total_amount', sa.Float(), nullable=False),
    sa.Column('gps_lat_delivery', sa.Float(), nullable=True),
    sa.Column('gps_lng_delivery', sa.Float(), nullable=True),
    sa.Column('status', sa.String(length=20), nullable=True),
    sa.ForeignKeyConstraint(['agent_id'], ['agents.id'], ),
    sa.ForeignKeyConstraint(['client_id'], ['clients.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    


def downgrade():
    
    op.drop_table('deliveries')
    op.drop_table('users')
    op.drop_table('clients')
    op.drop_table('agents')
    
