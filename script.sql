-- Update WLF_001_CASE_INVESTMENTS with current prices from WLF_001_CURRENT_PRICES
-- This script handles three scenarios:
-- 1. Successfully updates with current price when available and status is OK
-- 2. Falls back to old price when ticker is not found in current prices table
-- 3. Falls back to old price when ticker exists but status is NOK

UPDATE ci
SET 
    UPDT_CURRENT_PRICE = CASE 
        -- When current price is available and status is OK, use the updated price
        WHEN cp.UPDT_CURRENT_PRICE IS NOT NULL AND cp.STATUS = 'OK' THEN cp.UPDT_CURRENT_PRICE
        -- Otherwise, fall back to the old TIDES price
        ELSE ci.TIDES_CURRENT_PRICE
    END,
    
    UPDT_MRKT_VALUE = CASE 
        -- When current price is available and status is OK, calculate with updated price
        WHEN cp.UPDT_CURRENT_PRICE IS NOT NULL AND cp.STATUS = 'OK' THEN ci.TIDES_INV_QTY * cp.UPDT_CURRENT_PRICE
        -- Otherwise, fall back to the old TIDES market value
        ELSE ci.TIDES_MRKT_VALUE
    END,
    
    STATUS = CASE 
        -- When current price is available and status is OK, mark as OK
        WHEN cp.UPDT_CURRENT_PRICE IS NOT NULL AND cp.STATUS = 'OK' THEN 'OK'
        -- Otherwise, mark as NOK
        ELSE 'NOK'
    END,
    
    STATUS_MESSAGE = CASE 
        -- When current price is available and status is OK, clear the message
        WHEN cp.UPDT_CURRENT_PRICE IS NOT NULL AND cp.STATUS = 'OK' THEN 'Price updated successfully'
        -- When ticker exists but status is NOK, use the existing status message from current prices
        WHEN cp.UPDT_CURRENT_PRICE IS NOT NULL AND cp.STATUS = 'NOK' THEN ISNULL(cp.STATUS_MESSAGE, 'Unable to retrieve current price for ticker')
        -- When ticker doesn't exist in current prices table
        ELSE 'Unable to get current price for ticker - symbol not found'
    END,
    
    LAST_UPDATE = GETDATE(),
    LAST_USER = 'SYSTEM_UPDATE'

FROM WLF_001_CASE_INVESTMENTS ci
    INNER JOIN WLF_001_CASE_SUMMARY cs ON ci.CASE_ID = cs.CASE_ID
    LEFT JOIN WLF_001_CURRENT_PRICES cp ON ci.INV_SYMBOL = cp.INV_SYMBOL 
        AND cs.EXEC_ID = cp.EXEC_ID

-- Optional: Display summary of what was updated
SELECT 
    'Summary of Update Operation' as Operation,
    COUNT(*) as TotalRecordsProcessed,
    SUM(CASE WHEN STATUS = 'OK' THEN 1 ELSE 0 END) as SuccessfullyUpdated,
    SUM(CASE WHEN STATUS = 'NOK' THEN 1 ELSE 0 END) as FallbackToOldPrice
FROM WLF_001_CASE_INVESTMENTS ci
    INNER JOIN WLF_001_CASE_SUMMARY cs ON ci.CASE_ID = cs.CASE_ID
WHERE cs.EXEC_ID = cp.EXEC_ID  -- Replace with specific EXEC_ID if needed

-- Optional: If you want to update only for a specific EXEC_ID, add this WHERE clause to the main UPDATE:
-- WHERE cs.EXEC_ID = 'your-specific-exec-id-here'
