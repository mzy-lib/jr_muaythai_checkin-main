-- Fix expiry dates for class-based memberships
-- Description: Remove expiry dates for class-based membership types as they should not have expiry dates

BEGIN;

-- Update all class-based memberships to remove expiry date
UPDATE members
SET membership_expiry = NULL
WHERE membership IN ('single_class', 'two_classes', 'ten_classes')
AND membership_expiry IS NOT NULL;

COMMIT; 