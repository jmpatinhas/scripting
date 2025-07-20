-- Declare execution ID parameter (if running as a stored procedure or script)
DECLARE @EXEC_ID UNIQUEIDENTIFIER
-- SET @EXEC_ID = 'your-exec-id-value-here'  -- Uncomment and set your value

-- Update WLF_001_BCM_CASE_SUMMARY with aggregated market values and calculate deltas
UPDATE bcs
SET 
    UPDT_NON_CASH_POS = inv_agg.total_updated_market_value,
    
    UPDT_TOTAL_MARKET_VALUE = bcs.TIDES_CASH_POS + inv_agg.total_updated_market_value,
    
    DELTA = CASE 
        WHEN bcs.TIDES_NON_CASH_POS = 0 AND inv_agg.total_updated_market_value = 0 THEN 0
        WHEN bcs.TIDES_NON_CASH_POS = 0 AND inv_agg.total_updated_market_value != 0 THEN 1
        ELSE (inv_agg.total_updated_market_value - bcs.TIDES_NON_CASH_POS) / ABS(bcs.TIDES_NON_CASH_POS)
    END,
    
    UPDT_COVERAGE = CASE 
        WHEN inv_agg.total_updated_market_value = 0 THEN 0
        ELSE inv_agg.successfully_updated_market_value / inv_agg.total_updated_market_value
    END,
    
    STATUS = CASE 
        WHEN inv_agg.total_investments > 0 THEN 'OK'
        ELSE 'NOK'
    END,
    
    STATUS_MESSAGE = CASE 
        WHEN inv_agg.total_investments = 0 THEN 'No investments found for this case'
        WHEN inv_agg.successfully_updated_investments = inv_agg.total_investments THEN 'All investments successfully updated with current prices'
        WHEN inv_agg.successfully_updated_investments = 0 THEN 'No investments could be updated with current prices - using fallback values'
        ELSE CONCAT(
            'Partial update: ', 
            inv_agg.successfully_updated_investments, 
            ' of ', 
            inv_agg.total_investments, 
            ' investments updated with current prices'
        )
    END,
    
    LAST_UPDATE = GETDATE(),
    LAST_USER = 'SYSTEM_UPDATE'

FROM WLF_001_BCM_CASE_SUMMARY bcs
INNER JOIN (
    SELECT 
        ci.CASE_ID,
        SUM(ci.UPDT_MRKT_VALUE) as total_updated_market_value,
        SUM(CASE WHEN ci.STATUS = 'OK' THEN ci.UPDT_MRKT_VALUE ELSE 0 END) as successfully_updated_market_value,
        COUNT(*) as total_investments,
        SUM(CASE WHEN ci.STATUS = 'OK' THEN 1 ELSE 0 END) as successfully_updated_investments
    FROM WLF_001_CASE_INVESTMENTS ci
    INNER JOIN WLF_001_CASE_SUMMARY cs ON ci.CASE_ID = cs.CASE_ID
    WHERE cs.EXEC_ID = @EXEC_ID
    GROUP BY ci.CASE_ID
) inv_agg ON bcs.CASE_ID = inv_agg.CASE_ID
WHERE bcs.EXEC_ID = @EXEC_ID

-- Optional: Display summary of what was updated
SELECT 
    'Summary of BCM Case Summary Update' as Operation,
    COUNT(*) as TotalCasesProcessed,
    AVG(DELTA) as AverageDelta,
    AVG(UPDT_COVERAGE) as AverageCoverage,
    MIN(DELTA) as MinDelta,
    MAX(DELTA) as MaxDelta,
    MIN(UPDT_COVERAGE) as MinCoverage,
    MAX(UPDT_COVERAGE) as MaxCoverage
FROM WLF_001_BCM_CASE_SUMMARY
WHERE EXEC_ID = @EXEC_ID

-- Optional: Detailed view of results for verification
SELECT 
    bcs.CASE_ID,
    bcs.TIDES_NON_CASH_POS,
    bcs.UPDT_NON_CASH_POS,
    bcs.DELTA,
    bcs.UPDT_COVERAGE,
    bcs.STATUS,
    bcs.STATUS_MESSAGE
FROM WLF_001_BCM_CASE_SUMMARY bcs
WHERE bcs.EXEC_ID = @EXEC_ID
ORDER BY bcs.CASE_ID
