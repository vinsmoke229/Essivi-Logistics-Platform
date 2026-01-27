-- Migration: Ajout des colonnes de gestion du stock véhicule à la table tours
-- Date: 2026-01-25

ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_vitale_loaded INTEGER DEFAULT 0;
ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_voltic_loaded INTEGER DEFAULT 0;
ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_vitale_delivered INTEGER DEFAULT 0;
ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_voltic_delivered INTEGER DEFAULT 0;
ALTER TABLE tours ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'pending';

-- Commentaires pour documentation
COMMENT ON COLUMN tours.stock_vitale_loaded IS 'Quantité de packs Vitale emportés au démarrage de la tournée';
COMMENT ON COLUMN tours.stock_voltic_loaded IS 'Quantité de packs Voltic emportés au démarrage de la tournée';
COMMENT ON COLUMN tours.stock_vitale_delivered IS 'Quantité de packs Vitale livrés pendant la tournée';
COMMENT ON COLUMN tours.stock_voltic_delivered IS 'Quantité de packs Voltic livrés pendant la tournée';
COMMENT ON COLUMN tours.status IS 'Statut de la tournée: pending, in_progress, completed';
