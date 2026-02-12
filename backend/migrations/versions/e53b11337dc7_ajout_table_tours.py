"""Ajout table tours

Revision ID: e53b11337dc7
Revises: 9d56f0f3d0ad
Create Date: 2026-01-05 11:00:38.926818

"""
from alembic import op
import sqlalchemy as sa



revision = 'e53b11337dc7'
down_revision = '9d56f0f3d0ad'
branch_labels = None
depends_on = None


def upgrade():
    
    op.create_table('tours',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('agent_id', sa.Integer(), nullable=False),
    sa.Column('start_time', sa.DateTime(), nullable=True),
    sa.Column('end_time', sa.DateTime(), nullable=True),
    sa.Column('start_lat', sa.Float(), nullable=True),
    sa.Column('start_lng', sa.Float(), nullable=True),
    sa.Column('end_lat', sa.Float(), nullable=True),
    sa.Column('end_lng', sa.Float(), nullable=True),
    sa.Column('total_deliveries', sa.Integer(), nullable=True),
    sa.Column('total_cash_collected', sa.Float(), nullable=True),
    sa.ForeignKeyConstraint(['agent_id'], ['agents.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    


def downgrade():
    
    op.drop_table('tours')
    
