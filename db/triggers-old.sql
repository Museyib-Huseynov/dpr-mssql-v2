CREATE TRIGGER after_laboratory_results_insert
ON laboratory_results
AFTER INSERT
AS
BEGIN
    UPDATE wt
    SET water_cut = i.water_cut, 
        mechanical_impurities = i.mechanical_impurities
    FROM well_tests wt
    INNER JOIN inserted i ON wt.well_id = i.well_id
    WHERE wt.well_test_date >= i.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 WHERE lr1.last_lab_date > i.last_lab_date AND lr1.well_id = i.well_id
        )
        OR wt.well_test_date < (
            SELECT MIN(lr2.last_lab_date) 
            FROM laboratory_results lr2 
            WHERE lr2.last_lab_date > i.last_lab_date 
            AND lr2.well_id = i.well_id
        )
    );

    UPDATE dwp
    SET oil_loss_ton = CASE 
        WHEN dwp.water_cut = 100 OR (i.water_cut = 0 AND dwp.oil_density = 0) THEN 0
        ELSE (dwp.oil_loss_ton * (dwp.oil_density * (1 - dwp.water_cut / 100) + dwp.water_cut / 100) / (1 - dwp.water_cut / 100)) * (1 - i.water_cut / 100) / (dwp.oil_density * (1 - i.water_cut / 100) + i.water_cut / 100) 
    END,
        water_cut = i.water_cut,
        mechanical_impurities = i.mechanical_impurities
    FROM daily_well_parameters dwp
    INNER JOIN inserted i ON dwp.well_id = i.well_id
    WHERE (
        SELECT rd.report_date 
        FROM report_dates rd 
        WHERE rd.id = dwp.report_date_id
    ) >= i.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 WHERE lr1.last_lab_date > i.last_lab_date AND lr1.well_id = i.well_id
        )
        OR (SELECT rd.report_date FROM report_dates rd WHERE rd.id = dwp.report_date_id) < (
            SELECT MIN(lr2.last_lab_date) 
            FROM laboratory_results lr2 
            WHERE lr2.last_lab_date > i.last_lab_date 
            AND lr2.well_id = i.well_id
        )
    );
END;
GO

CREATE TRIGGER after_laboratory_results_delete
ON laboratory_results
AFTER DELETE
AS
BEGIN
    DECLARE @last_available_water_cut FLOAT;
    DECLARE @last_available_mechanical_impurities FLOAT;

    SELECT TOP 1 @last_available_water_cut = water_cut, 
                  @last_available_mechanical_impurities = mechanical_impurities
    FROM laboratory_results
    WHERE well_id = (SELECT well_id FROM deleted) 
    AND last_lab_date < (SELECT last_lab_date FROM deleted)
    ORDER BY last_lab_date DESC;

    UPDATE wt
    SET water_cut = @last_available_water_cut, 
        mechanical_impurities = @last_available_mechanical_impurities
    FROM well_tests wt
    INNER JOIN deleted d ON wt.well_id = d.well_id
    WHERE wt.well_test_date >= d.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 WHERE lr1.last_lab_date > d.last_lab_date AND lr1.well_id = d.well_id
        )
        OR wt.well_test_date < (
            SELECT MIN(lr2.last_lab_date) 
            FROM laboratory_results lr2 
            WHERE lr2.last_lab_date > d.last_lab_date 
            AND lr2.well_id = d.well_id
        )
    );

    UPDATE dwp
    SET oil_loss_ton = CASE 
        WHEN dwp.water_cut = 100 OR (d.water_cut = 0 AND dwp.oil_density = 0) THEN 0
        ELSE (dwp.oil_loss_ton * (dwp.oil_density * (1 - dwp.water_cut / 100) + dwp.water_cut / 100) / (1 - dwp.water_cut / 100)) * (1 - d.water_cut / 100) / (dwp.oil_density * (1 - d.water_cut / 100) + d.water_cut / 100) 
    END,
        water_cut = @last_available_water_cut,
        mechanical_impurities = @last_available_mechanical_impurities
    FROM daily_well_parameters dwp
    INNER JOIN deleted d ON dwp.well_id = d.well_id
    WHERE (
        SELECT rd.report_date 
        FROM report_dates rd 
        WHERE rd.id = dwp.report_date_id
    ) >= d.last_lab_date
    AND (
        NOT EXISTS (
            SELECT 1 FROM laboratory_results lr1 WHERE lr1.last_lab_date > d.last_lab_date AND lr1.well_id = d.well_id
        )
        OR (SELECT rd.report_date FROM report_dates rd WHERE rd.id = dwp.report_date_id) < (
            SELECT MIN(lr2.last_lab_date) 
            FROM laboratory_results lr2 
            WHERE lr2.last_lab_date > d.last_lab_date 
            AND lr2.well_id = d.well_id
        )
    );
END;
GO
