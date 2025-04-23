CREATE PROCEDURE DeleteTodayEntries
AS
BEGIN
    DELETE FROM flowmeters WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM well_stock WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM completions WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM well_downtime_reasons WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM daily_well_parameters WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM well_tests WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
    DELETE FROM laboratory_results WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);
END;
GO

CREATE PROCEDURE DeleteAllEntries
AS
BEGIN
    TRUNCATE TABLE flowmeters;
    TRUNCATE TABLE well_stock;
    TRUNCATE TABLE completions;
    TRUNCATE TABLE well_downtime_reasons;
    TRUNCATE TABLE daily_well_parameters;
    TRUNCATE TABLE well_tests;
    TRUNCATE TABLE laboratory_results;
END;
GO

CREATE PROCEDURE DeleteEntries
    @reportDate DATE,
    @platform INT
AS
BEGIN
    DECLARE @reportDateId INT;

    SELECT @reportDateId = rd.id
    FROM report_dates AS rd
    WHERE rd.report_date = @reportDate;

    DELETE flowmeters
    FROM flowmeters
    INNER JOIN platforms ON flowmeters.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE well_stock
    FROM well_stock
    INNER JOIN wells ON well_stock.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE completions
    FROM completions
    INNER JOIN wells ON completions.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE well_downtime_reasons
    FROM well_downtime_reasons
    INNER JOIN wells ON well_downtime_reasons.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE daily_well_parameters
    FROM daily_well_parameters
    INNER JOIN wells ON daily_well_parameters.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE well_tests
    FROM well_tests
    INNER JOIN wells ON well_tests.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);

    DELETE laboratory_results
    FROM laboratory_results
    INNER JOIN wells ON laboratory_results.well_id = wells.id
    INNER JOIN platforms ON wells.platform_id = platforms.id
    WHERE report_date_id = @reportDateId AND (platforms.name = @platform OR @platform IS NULL);
END;
GO