CREATE VIEW complete_table AS
SELECT 
    rd.report_date AS report_date,
    p.name AS platform,
    w.name AS well,
    wsc.name AS well_stock_category,
    wssc.name AS well_stock_sub_category,
    pwssc.name AS production_well_stock_sub_category,
    pm.name AS production_method,
    h.name AS horizon,
    dwp.flowmeter AS flowmeter,
    dwp.well_uptime_hours AS well_uptime_hours,
    dwp.choke AS choke,
    dwp.pqa AS Pqa,
    dwp.phf AS Phf,
    dwp.pba AS Pba,
    dwp.p6x9 AS P6x9,
    dwp.p9x13 AS P9x13,
    dwp.p13x20 AS P13x20,
    ROUND(dwp.liquid_ton, 0) AS liquid_ton,
    CASE
        WHEN dwp.oil_density = 0 AND dwp.water_cut = 0 THEN 0
        ELSE ROUND(dwp.liquid_ton * (dwp.water_cut / 100) / (dwp.oil_density * (1 - (dwp.water_cut / 100)) + (dwp.water_cut / 100)), 0)
    END AS water_ton,
    CASE
        WHEN dwp.oil_density = 0 AND dwp.water_cut = 0 THEN 0
        ELSE ROUND(dwp.liquid_ton * dwp.oil_density * (1 - (dwp.water_cut / 100)) / (dwp.oil_density * (1 - (dwp.water_cut / 100)) + (dwp.water_cut / 100)), 0)
    END AS oil_ton,
    ROUND(dwp.total_gas, 0) AS total_gas,
    ROUND(dwp.gaslift_gas, 0) AS gaslift_gas,
    ROUND((wt.total_gas - wt.gaslift_gas) * dwp.well_uptime_hours / 24, 0) AS produced_gas,
    ROUND(dwp.reported_water_cut, 1) AS reported_water_cut,
    ROUND(dwp.water_cut, 1) AS allocated_water_cut,
    ROUND(dwp.mechanical_impurities, 1) AS mechanical_impurities,
    ROUND(dwp.oil_density, 3) AS oil_density,
    ROUND(dwp.oil_loss_ton, 0) AS oil_loss_ton,
    wdr.downtime_category AS donwtime_category,
    pssa.name AS production_skin,
    wdr.comments AS comments
FROM daily_well_parameters dwp
LEFT JOIN well_stock AS ws
    ON dwp.well_id = ws.well_id
    AND ws.report_date_id = (
        SELECT MAX(ws_sub.report_date_id)
        FROM well_stock AS ws_sub
        WHERE ws_sub.well_id = dwp.well_id
        AND ws_sub.report_date_id <= dwp.report_date_id
    )
LEFT JOIN completions AS c
    ON dwp.well_id = c.well_id
    AND c.report_date_id = (
        SELECT MAX(c_sub.report_date_id)
        FROM completions AS c_sub
        WHERE c_sub.well_id = dwp.well_id
        AND c_sub.report_date_id <= dwp.report_date_id
    )
LEFT JOIN well_downtime_reasons AS wdr
    ON dwp.well_id = wdr.well_id
    AND wdr.report_date_id = (
        SELECT MAX(wdr_sub.report_date_id)
        FROM well_downtime_reasons AS wdr_sub
        WHERE wdr_sub.well_id = dwp.well_id
        AND wdr_sub.report_date_id <= dwp.report_date_id
    )
LEFT JOIN well_tests AS wt
    ON dwp.well_id = wt.well_id
    AND wt.report_date_id = (
        SELECT MAX(wt_sub.report_date_id)
        FROM well_tests AS wt_sub
        WHERE wt_sub.well_id = dwp.well_id
        AND wt_sub.report_date_id <= dwp.report_date_id
    )
LEFT JOIN wells AS w
    ON dwp.well_id = w.id
LEFT JOIN platforms AS p
    ON w.platform_id = p.id
LEFT JOIN report_dates AS rd
    ON dwp.report_date_id = rd.id
LEFT JOIN well_stock_categories AS wsc
    ON ws.well_stock_category_id = wsc.id
LEFT JOIN well_stock_sub_categories AS wssc
    ON ws.well_stock_sub_category_id = wssc.id
LEFT JOIN production_well_stock_sub_categories AS pwssc
    ON ws.production_well_stock_sub_category_id = pwssc.id
LEFT JOIN production_methods AS pm
    ON ws.production_method_id = pm.id
LEFT JOIN horizons AS h
    ON c.horizon_id = h.id
LEFT JOIN production_sub_skins_activities AS pssa
    ON wdr.production_sub_skins_activity_id = pssa.id;
