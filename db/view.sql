use dpr;
GO

DROP VIEW complete_table;
GO

CREATE VIEW complete_table AS

SELECT 
  rd.report_date AS report_date,
  f.name AS field,
  CASE
        WHEN p.square IS NULL OR p.square = '' THEN p.name
        ELSE p.name + ' / ' + p.square
      END AS platform,
  w.name AS well,
  wsc.name AS well_stock_category,
  pwssc.name AS production_well_stock_sub_category,
  pm.name AS production_method,
  h.name AS horizon,
  dwp.flowmeter AS flowmeter,
  dwp.well_uptime_hours AS well_uptime_hours,
  ROUND(wt.liquid_ton, 0) AS liquid_ton,
  ROUND(lr.water_cut, 1) AS water_cut,
  oil_ton_calc AS oil_ton_wellTest,
  (
    SELECT mr.produced_oil / DAY(rd_sub.report_date)
    FROM monthly_reported mr
    INNER JOIN report_dates rd_sub ON mr.report_date_id = rd_sub.id
    WHERE mr.field_id = f.id AND rd_sub.report_date = EOMONTH(rd.report_date)
  ) * 
  oil_ton_calc /
  NULLIF(
    SUM(oil_ton_calc) OVER (PARTITION BY f.id, rd.report_date), 0
  ) AS allocated_oil_ton,
  ISNULL(oil_ton_calc * (24 - dwp.well_uptime_hours) / 24, 0) AS oil_loss_ton_wellTest,
  water_ton_calc AS water_ton,
  ROUND(gwt.total_gas, 0) AS total_gas,
  ROUND(gwt.gaslift_gas, 0) AS gaslift_gas,
  ROUND((gwt.total_gas - gwt.gaslift_gas) * dwp.well_uptime_hours / 24, 0) AS produced_gas,
  ROUND(lr.mechanical_impurities, 1) AS mechanical_impurities,
  dwp.pqa AS Pqa,
  dwp.phf AS Phf,
  dwp.pba AS Pba,
  dwp.p6x9 AS P6x9,
  dwp.p9x13 AS P9x13,
  dwp.p13x20 AS P13x20,
  dwp.choke AS choke,
  dwp.gaslift_gas AS gaslift_gas_daily,
  dwp.gaslift_system_pressure AS gaslift_system_pressure,
  dwp.pump_depth AS pump_depth,
  dwp.pump_frequency AS pump_frequency,
  dwp.pump_hydrostatic_pressure AS pump_hydrostatic_pressure,
  dwp.esp_pump_size AS esp_pump_size,
  dwp.esp_pump_stages AS esp_pump_stages,
  dwp.esp_pump_rate AS esp_pump_rate,
  dwp.esp_pump_head AS esp_pump_head,
  dwp.esp_downhole_gas_separator AS esp_downhole_gas_separator,
  dwp.srp_pumpjack_type AS srp_pumpjack_type,
  dwp.srp_pump_plunger_diameter AS srp_pump_plunger_diameter,
  dwp.srp_plunger_stroke_length AS srp_plunger_stroke_length,
  dwp.srp_balancer_oscillation_frequency AS srp_balancer_oscillation_frequency,
  dwp.srp_pump_rate_coefficient AS srp_pump_rate_coefficient,
  dwp.srp_max_motor_speed AS srp_max_motor_speed,
  dwp.srp_shaft_diameter AS srp_shaft_diameter,
  dwp.pcp_pump_rate AS pcp_pump_rate,
  dwp.pcp_rpm AS pcp_rpm,
  dwp.pcp_screw_diameter AS pcp_screw_diameter,
  dwp.static_fluid_level AS static_fluid_level,
  dwp.dynamic_fluid_level AS dynamic_fluid_level,
  wdr.downtime_category AS donwtime_category,
  pssa.name AS production_skin,
  wdr.comments AS comments
FROM daily_well_parameters AS dwp

OUTER APPLY (
  SELECT TOP 1 *
  FROM well_stock ws_sub
  WHERE ws_sub.well_id = dwp.well_id
    AND ws_sub.report_date_id <= dwp.report_date_id
  ORDER BY ws_sub.report_date_id DESC
) ws

OUTER APPLY (
  SELECT TOP 1 *
  FROM completions c_sub
  WHERE c_sub.well_id = dwp.well_id
    AND c_sub.report_date_id <= dwp.report_date_id
  ORDER BY c_sub.report_date_id DESC
) c

OUTER APPLY (
  SELECT TOP 1 *
  FROM well_downtime_reasons wdr_sub
  WHERE wdr_sub.well_id = dwp.well_id
    AND wdr_sub.report_date_id <= dwp.report_date_id
  ORDER BY wdr_sub.report_date_id DESC
) wdr

OUTER APPLY (
  SELECT TOP 1 *
  FROM well_tests wt_sub
  WHERE wt_sub.well_id = dwp.well_id
    AND wt_sub.report_date_id <= dwp.report_date_id
  ORDER BY wt_sub.report_date_id DESC
) wt

OUTER APPLY (
  SELECT TOP 1 *
  FROM laboratory_results lr_sub
  WHERE lr_sub.well_id = dwp.well_id
    AND lr_sub.report_date_id <= dwp.report_date_id
  ORDER BY lr_sub.report_date_id DESC
) lr

OUTER APPLY (
  SELECT TOP 1 *
  FROM gas_well_tests gwt_sub
  WHERE gwt_sub.well_id = dwp.well_id
    AND gwt_sub.report_date_id <= dwp.report_date_id
  ORDER BY gwt_sub.report_date_id DESC
) gwt

LEFT JOIN report_dates AS rd
    ON dwp.report_date_id = rd.id

LEFT JOIN wells AS w
    ON dwp.well_id = w.id

LEFT JOIN platforms AS p
    ON w.platform_id = p.id

LEFT JOIN fields AS f
    ON p.field_id = f.id

LEFT JOIN well_stock_categories AS wsc
    ON ws.well_stock_category_id = wsc.id

LEFT JOIN production_well_stock_sub_categories AS pwssc
    ON ws.production_well_stock_sub_category_id = pwssc.id

LEFT JOIN production_methods AS pm
    ON ws.production_method_id = pm.id

LEFT JOIN horizons AS h
    ON c.horizon_id = h.id

LEFT JOIN production_sub_skins_activities AS pssa
    ON wdr.production_sub_skins_activity_id = pssa.id

CROSS APPLY (
  SELECT
    oil_ton_calc =
      CASE
          WHEN f.name <> N'Günəşli' THEN ISNULL(wt.oil_ton, 0)
          WHEN h.oil_density = 0 AND lr.water_cut = 0 THEN 0
          ELSE ROUND(wt.liquid_ton * h.oil_density * (1 - (lr.water_cut / 100)) /
              (h.oil_density * (1 - (lr.water_cut / 100)) + (lr.water_cut / 100)), 0)
      END,

    water_ton_calc =
      CASE
          WHEN f.name <> N'Günəşli' THEN ISNULL(wt.water_ton, 0)
          WHEN h.oil_density = 0 AND lr.water_cut = 0 THEN 0
          ELSE ROUND(wt.liquid_ton * (lr.water_cut / 100) /
              (h.oil_density * (1 - (lr.water_cut / 100)) + (lr.water_cut / 100)), 0)
      END
) AS calc


