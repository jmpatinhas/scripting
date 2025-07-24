-- Script to identify users who stayed above 9GB usage for a full month
-- Assumes weekly RPA execution creates records each week

DECLARE @TargetMonth INT = MONTH(GETDATE()); -- Current month, adjust as needed
DECLARE @TargetYear INT = YEAR(GETDATE());   -- Current year, adjust as needed
DECLARE @MinWeeksInMonth INT = 4;            -- Minimum weeks to consider "full month"

WITH MonthlyUserData AS (
    -- Get all records for the target month
    SELECT 
        USER_NAME,
        FIRST_NAME,
        LAST_NAME,
        EMAIL,
        USED_STORAGE_GB,
        CREATION_DATE,
        -- Calculate week number within the month
        DATEPART(WEEK, CREATION_DATE) - DATEPART(WEEK, DATEFROMPARTS(@TargetYear, @TargetMonth, 1)) + 1 AS WeekInMonth,
        -- Rank records by creation date for each user (in case of multiple records per week)
        ROW_NUMBER() OVER (PARTITION BY USER_NAME, DATEPART(WEEK, CREATION_DATE) ORDER BY CREATION_DATE DESC) as rn
    FROM DM_003_ESN_USERS
    WHERE MONTH(CREATION_DATE) = @TargetMonth 
      AND YEAR(CREATION_DATE) = @TargetYear
      AND ACTIVE = 'TRUE'
      AND USED_STORAGE_GB IS NOT NULL
),
WeeklyMaxUsage AS (
    -- Get the latest record per user per week (in case multiple records exist)
    SELECT 
        USER_NAME,
        FIRST_NAME,
        LAST_NAME,
        EMAIL,
        USED_STORAGE_GB,
        CREATION_DATE,
        WeekInMonth
    FROM MonthlyUserData
    WHERE rn = 1
),
UserMonthlyStats AS (
    -- Calculate statistics for each user
    SELECT 
        USER_NAME,
        FIRST_NAME,
        LAST_NAME,
        EMAIL,
        COUNT(*) as WeeksWithData,
        MIN(USED_STORAGE_GB) as MinUsageGB,
        MAX(USED_STORAGE_GB) as MaxUsageGB,
        AVG(USED_STORAGE_GB) as AvgUsageGB,
        -- Count weeks where usage was above 9GB
        SUM(CASE WHEN USED_STORAGE_GB > 9 THEN 1 ELSE 0 END) as WeeksAbove9GB,
        -- Get all weekly usage values as a string for reference
        STRING_AGG(CAST(USED_STORAGE_GB as VARCHAR(10)), ', ') WITHIN GROUP (ORDER BY WeekInMonth) as WeeklyUsagePattern
    FROM WeeklyMaxUsage
    GROUP BY USER_NAME, FIRST_NAME, LAST_NAME, EMAIL
)
-- Final result: Users who stayed above 9GB for the entire month
SELECT 
    USER_NAME,
    FIRST_NAME,
    LAST_NAME,
    EMAIL,
    WeeksWithData,
    WeeksAbove9GB,
    MinUsageGB,
    MaxUsageGB,
    AvgUsageGB,
    WeeklyUsagePattern,
    CASE 
        WHEN WeeksAbove9GB = WeeksWithData AND WeeksWithData >= @MinWeeksInMonth 
        THEN 'YES - Stayed above 9GB all month'
        WHEN WeeksAbove9GB >= @MinWeeksInMonth 
        THEN 'MOSTLY - Above 9GB for most weeks'
        ELSE 'NO - Did not consistently stay above 9GB'
    END as ConsistentHighUsage
FROM UserMonthlyStats
WHERE WeeksWithData >= @MinWeeksInMonth  -- Only users with sufficient data
ORDER BY WeeksAbove9GB DESC, AvgUsageGB DESC;

-- Additional query: Summary statistics
SELECT 
    COUNT(*) as TotalUsersAnalyzed,
    SUM(CASE WHEN WeeksAbove9GB = WeeksWithData AND WeeksWithData >= @MinWeeksInMonth THEN 1 ELSE 0 END) as UsersConsistentlyAbove9GB,
    SUM(CASE WHEN WeeksAbove9GB >= @MinWeeksInMonth THEN 1 ELSE 0 END) as UsersMostlyAbove9GB
FROM UserMonthlyStats
WHERE WeeksWithData >= @MinWeeksInMonth;
