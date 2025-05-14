DROP INDEX IDX_c_horizonId ON completions;
GO
DROP INDEX IDX_c_reportDateId ON completions;
GO
DROP INDEX IDX_c_wellId ON completions;
GO

CREATE NONCLUSTERED INDEX IDX_c_well_date
ON completions (well_id, report_date_id DESC)
INCLUDE (horizon_id, casing, completion_interval, tubing1_depth, tubing1_length, tubing2_depth, tubing2_length, tubing3_depth, tubing3_length, packer_depth);
GO

--

DROP INDEX IDX_dgc_fieldId ON daily_general_comments;
GO
DROP INDEX IDX_dgc_reportDateId ON daily_general_comments;
GO

--

DROP INDEX IDX_do_ogpdId ON daily_operatives;
GO
DROP INDEX IDX_do_reportDateId ON daily_operatives;
GO

--

DROP INDEX IDX_dwp_reportDateId ON daily_well_parameters;
GO
DROP INDEX IDX_dwp_wellId ON daily_well_parameters;
GO

CREATE NONCLUSTERED INDEX IDX_dwp_well_date
ON daily_well_parameters (well_id, report_date_id DESC)
INCLUDE (flowmeter, well_uptime_hours, choke, pqa, phf, pba, p6x9, p9x13, p13x20, gaslift_gas, gaslift_system_pressure, pump_depth, pump_frequency, pump_hydrostatic_pressure, esp_pump_size, esp_pump_stages, esp_pump_rate, esp_pump_head, esp_downhole_gas_separator, srp_pumpjack_type, srp_pump_plunger_diameter, srp_plunger_stroke_length, srp_balancer_oscillation_frequency, srp_pump_rate_coefficient, srp_max_motor_speed, srp_shaft_diameter, pcp_pump_rate, pcp_rpm, pcp_screw_diameter, static_fluid_level, dynamic_fluid_level);
GO

--

DROP INDEX IDX_gwt_reportDateId ON gas_well_tests;
GO
DROP INDEX IDX_gwt_wellId ON gas_well_tests;
GO

CREATE NONCLUSTERED INDEX IDX_gwt_well_date
ON gas_well_tests (well_id, report_date_id DESC)
INCLUDE (well_test_date, total_gas, gaslift_gas);
GO

--

CREATE NONCLUSTERED INDEX IDX_h_id_density
ON horizons (id)
INCLUDE (oil_density);
GO

--

DROP INDEX IDX_lr_report_date_id ON laboratory_results;
GO
DROP INDEX IDX_lr_wellId ON laboratory_results;
GO

CREATE NONCLUSTERED INDEX IDX_lr_well_date
ON laboratory_results (well_id, report_date_id DESC)
INCLUDE (water_cut, mechanical_impurities);
GO

--

DROP INDEX IDX_mr_fieldId ON monthly_reported;
GO
DROP INDEX IDX_mr_reportDateId ON monthly_reported;
GO

CREATE NONCLUSTERED INDEX IDX_mr_field_date
ON monthly_reported (field_id, report_date_id)
INCLUDE (produced_oil, produced_condensate, produced_gas, produced_water, injected_water);

--

CREATE NONCLUSTERED INDEX IDX_ws_well_date
ON well_stock (well_id, report_date_id DESC)
GO

--

CREATE NONCLUSTERED INDEX IDX_wt_well_date
ON well_tests (well_id, report_date_id DESC)
INCLUDE (well_test_date, liquid_ton, oil_ton, water_ton);
GO

--