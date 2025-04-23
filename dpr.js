import { promises as fs, createWriteStream, existsSync, mkdirSync } from 'fs';
import path from 'path';
import mssql from 'mssql';
import officeCrypto from 'officecrypto-tool';
import readXlsxFile from 'read-excel-file/node';
import chalk from 'chalk';

const inputFolder = process.argv[2] || './';
const password = 'gun123';

//// generate logger function to log to console and local file
if (!existsSync('./logs')) {
  mkdirSync('./logs', { recursive: true });
}
const logFilePath = getFormattedFilename();

const stream = createWriteStream(logFilePath, { flags: 'a' });

let logger_without_timestamp = false;
const success = 'SUCCESS';
const error = 'ERROR';
const warning = 'WARNING';

let success_count = 0;
let error_count = 0;
let warning_count = 0;
let info_count = 0;

let flowmeter_insertion_count = 0;
let well_stock_insertion_count = 0;
let completion_insertion_count = 0;
let well_tests_insertion_count = 0;
let daily_well_parameters_insertion_count = 0;
let well_downtime_reasons_insertion_count = 0;
let laboratory_results_insertion_count = 0;

const logger = {
  log: (message, level = 'INFO') => {
    const timestamp = new Date().toLocaleString('en-US', {
      timeZone: 'Asia/Baku',
      hour12: false,
    });

    let style;
    if (level === success) {
      style = chalk.green;
      success_count++;
    } else if (level === error) {
      style = chalk.red;
      error_count++;
    } else if (level === warning) {
      style = chalk.yellow;
      warning_count++;
    } else if (level === 'INFO' && logger_without_timestamp === false) {
      info_count++;
    }

    let content;
    if (logger_without_timestamp) {
      content = `\n${message}`;
    } else {
      content = `\n${timestamp} ${`[${level}]:`.padStart(10)} ${message}`;
    }

    stream.write(content);
    console.log(content);
  },
  close: () => stream.end(),
};
////

let pool;
try {
  logger_without_timestamp = true;
  logger.log(`${'*'.repeat(100)}`);
  logger.log('SCRIPT EXECUTION STARTED...');
  logger_without_timestamp = false;

  pool = await mssql.connect(
    'Server=localhost,1433;Database=dpr;User Id=museyib;Password=3231292;Encrypt=false'
  );

  const { recordset: wells } = await pool
    .request()
    .query('SELECT * FROM wells');
  const { recordset: platforms } = await pool
    .request()
    .query('SELECT * FROM platforms');
  const { recordset: well_stock_categories } = await pool
    .request()
    .query('SELECT * FROM well_stock_categories');
  const { recordset: well_stock_sub_categories } = await pool
    .request()
    .query('SELECT * FROM well_stock_sub_categories');
  const { recordset: production_well_stock_sub_categories } = await pool
    .request()
    .query('SELECT * FROM production_well_stock_sub_categories');
  const { recordset: production_methods } = await pool
    .request()
    .query('SELECT * FROM production_methods');
  const { recordset: horizons } = await pool
    .request()
    .query('SELECT * FROM horizons');
  const { recordset: production_sub_skins_activities } = await pool
    .request()
    .query('SELECT * FROM production_sub_skins_activities');
  ////

  //// Go through files in folder specified in `inputFolder`, find `.xls` or `xlsx` files, decrypt them, parse each cell from Excel files, insert into db
  const files = await fs.readdir(inputFolder);

  outer: for (const file of files) {
    const filePath = path.join(inputFolder, file);
    const extension = path.extname(file).toLowerCase();
    if (extension === '.xls' || extension === '.xlsx') {
      logger_without_timestamp = true;
      logger.log(`${'='.repeat(100)}`);
      logger.log(`|'${filePath}'| Parsing...`);
      logger_without_timestamp = false;

      const input = await fs.readFile(filePath);
      const isEncrypted = officeCrypto.isEncrypted(input);
      let output;
      if (isEncrypted) {
        output = await officeCrypto.decrypt(input, { password });
        await fs.writeFile(filePath, output);
      } else {
        output = input;
      }
      const rows = await readXlsxFile(output, { sheet: 'Hesabat forması' });

      // parse platform_id
      const platform_number = rows[18][4];
      const platform_id = platforms.find(
        (i) => i.name === Number(platform_number)
      )?.id;
      if (!platform_id) {
        logger.log(`Platform number is not correct in excel file`, error);
        logger.log(`Data is not persisted into DB!`, warning);
        continue outer;
      }
      //

      // parse report_date
      let report_date = rows[17][4];
      if (!isValidDate(report_date)) {
        logger.log(`Report_date is not correct`, error);
        logger.log(`Data is not persisted into DB!`, warning);
        continue outer;
      }
      report_date = processDateValue(report_date);

      const get_report_date_id_query =
        'SELECT id FROM report_dates WHERE report_date = @report_date';

      const { recordset: report_date_query_result } = await pool
        .request()
        .input('report_date', report_date)
        .query(get_report_date_id_query);

      const { id: report_date_id } = report_date_query_result[0] || {};
      //

      // rename excel file to keep it clean
      const newFileName = `DPR-${platform_number}-${report_date}.xlsx`;
      const newFilePath = path.join(path.dirname(filePath), newFileName);
      await fs.rename(filePath, newFilePath);
      //

      // check if report is yesterday's report
      // const today = new Date().toLocaleDateString('en-CA', {
      //   timeZone: 'Asia/Baku',
      // });
      // const diffDays = (new Date(today) - new Date(report_date)) / 86400000;
      // if (diffDays !== 1) {
      //   logger.log(`Report_date is not yesterday's`, error);
      //   logger.log(`Data is not persisted into DB!`, warning);
      //   continue outer;
      // }
      //

      // parse flowmeter params
      const reading1 = rows[17][56];
      const reading2 = rows[18][56];
      const reading3 = rows[17][58];
      const reading4 = rows[18][58];
      let calibration_date = rows[20][56];
      if (isValidDate(calibration_date)) {
        calibration_date = processDateValue(calibration_date);
      } else {
        calibration_date = null;
      }
      //

      //// populate flowmeters table
      logger_without_timestamp = true;
      logger.log(`${'-'.repeat(100)}`);
      logger.log(
        `|'Report Date: ${report_date}'|'Platform ${platform_number}'|'flowmeters table'| populating DB...`
      );
      logger_without_timestamp = false;

      // check flowmeters entry exists in DB
      const flowmeters_entry_exists_query =
        'SELECT COUNT(*) AS flowmeters_entry_exists FROM flowmeters WHERE platform_id = @platform_id AND report_date_id = @report_date_id';

      const { recordset: flowmeters_entry_exists_query_result } = await pool
        .request()
        .input('platform_id', platform_id)
        .input('report_date_id', report_date_id)
        .query(flowmeters_entry_exists_query);

      const { flowmeters_entry_exists } =
        flowmeters_entry_exists_query_result[0] || {};
      //

      // get previous entry from flowmeters table
      const flowmeters_previous_entry_query =
        'SELECT TOP 1 * FROM flowmeters WHERE platform_id = @platform_id AND report_date_id < @report_date_id ORDER BY report_date_id DESC';

      const { recordset: flowmeters_previous_entry_query_result } = await pool
        .request()
        .input('platform_id', platform_id)
        .input('report_date_id', report_date_id)
        .query(flowmeters_previous_entry_query);

      const {
        report_date_id: flowmeters_previous_entry_report_date_id,
        reading1: flowmeters_previous_entry_reading1,
        reading2: flowmeters_previous_entry_reading2,
        reading3: flowmeters_previous_entry_reading3,
        reading4: flowmeters_previous_entry_reading4,
      } = flowmeters_previous_entry_query_result[0] || {};

      const flowmeters_previous_entry_is_yesterday = isYesterday(
        report_date_id,
        flowmeters_previous_entry_report_date_id
      );
      //

      // insert entry into flowmeter table
      const flowmeters_insert_query =
        'INSERT INTO flowmeters (platform_id, report_date_id, reading1, reading2, reading3, reading4, calibration_date) VALUES (@platform_id, @report_date_id, @reading1, @reading2, @reading3, @reading4, @calibration_date)';

      if (![2, 3, 4, 7, 8, 13].includes(platform_number)) {
        logger.log(`Flowmeter is not present`);
        logger.log(`Not populated!`);
      } else if (
        reading2 == null ||
        reading4 == null ||
        ([8, 13].includes(platform_number) &&
          (reading1 == null || reading3 == null))
      ) {
        logger.log(`Check flowmeter parameters`, error);
        logger.log(`Not populated!`, warning);
      } else if (
        flowmeters_previous_entry_is_yesterday &&
        [8, 13].includes(platform_number) &&
        (flowmeters_previous_entry_reading2 != reading1 ||
          flowmeters_previous_entry_reading4 != reading3)
      ) {
        logger.log(
          `Yesterday's flowmeter reading should be same with yesterday's, but different!`,
          error
        );
      } else if (!Number(flowmeters_entry_exists)) {
        await pool
          .request()
          .input('platform_id', platform_id)
          .input('report_date_id', report_date_id)
          .input('reading1', reading1)
          .input('reading2', reading2)
          .input('reading3', reading3)
          .input('reading4', reading4)
          .input('calibration_date', calibration_date)
          .query(flowmeters_insert_query);
        logger.log(`Populated!`, success);
        flowmeter_insertion_count++;
        // check whether today's flowmeter params same as yesterday's (show warning)
        if (
          flowmeters_previous_entry_is_yesterday &&
          [2, 3, 4, 7].includes(platform_number) &&
          (flowmeters_previous_entry_reading2 == reading2 ||
            flowmeters_previous_entry_reading4 == reading4)
        ) {
          logger.log(
            `Today's Flowmeter params are same as yesterday's!`,
            warning
          );
        }
        //
      } else {
        logger.log(`Already populated!`);
      }
      //
      ////

      //// looping through rows (wells)
      inner: for (let i = 28; i < rows.length; i++) {
        const row = rows[i];
        if (row[2] === null) break;

        let validation_error = false;

        const well_number = row[3];
        const well_id = wells.find(
          (i) => i.name.trim() === String(well_number).trim()
        )?.id;

        // check if well name is specified correctly
        if (!well_id) {
          logger_without_timestamp = true;
          logger.log(`${'-'.repeat(100)}`);
          logger_without_timestamp = false;

          logger.log(
            `Check |'Platform ${platform_number}'|'row-${
              i + 1
            }'| Well name is not correct`,
            error
          );
          logger.log(
            `Check |'Platform ${platform_number}'|'row-${
              i + 1
            }'| Data is not persisted into DB!`,
            warning
          );
          continue inner;
        }
        //

        logger_without_timestamp = true;
        logger.log(`${'-'.repeat(100)}`);
        logger.log(
          `|'Report Date: ${report_date}'|'Platform ${platform_number}'|'Well ${well_number}'| populating DB...`
        );
        logger_without_timestamp = false;

        const well_stock_category_id = well_stock_categories.find(
          (i) => i.name.trim() === row[4]?.trim?.()
        )?.id;
        const well_stock_sub_category_id = well_stock_sub_categories.find(
          (i) => i.name.trim() === row[5]?.trim?.()
        )?.id;
        const production_well_stock_sub_category_id =
          production_well_stock_sub_categories.find(
            (i) => i.name.trim() === row[6]?.trim?.()
          )?.id;
        const production_method_id = production_methods.find(
          (i) => i.name.trim() === row[7]?.trim?.()
        )?.id;
        const horizon_id = horizons.find(
          (i) => i.name.trim() === row[8]?.trim?.()
        )?.id;

        const casing = row[9];
        const completion_interval = row[10];
        const tubing1_depth = row[11];
        const tubing1_length = row[12];
        const tubing2_depth = row[13];
        const tubing2_length = row[14];
        const tubing3_depth = row[15];
        const tubing3_length = row[16];
        const packer_depth = row[17];
        const flowmeter = row[18];

        let last_well_test_date = row[19];
        let last_lab_date = row[35];

        // check if dates are in correct format
        if (!isValidDate(last_well_test_date) || !isValidDate(last_lab_date)) {
          logger.log(
            `Check 'last_well_test_date or last_lab_date is not correct'`,
            error
          );
          validation_error = true;
        } else {
          last_well_test_date = processDateValue(last_well_test_date);
          last_lab_date = processDateValue(last_lab_date);
        }
        //

        const choke_wt = row[20];
        const pqa_wt = row[21];
        const phf_wt = row[22];
        const pba_wt = row[23];
        const p6x9_wt = row[24];
        const p9x13_wt = row[25];
        const p13x20_wt = row[26];
        const liquid_ton = row[27];
        const oil_density = row[30];
        const total_gas = row[32];
        const gaslift_gas_wt = row[33];
        const water_cut = row[36];
        const mechanical_impurities = row[37];
        const well_uptime_hours = row[38];
        const choke_day = row[39];
        const pqa_day = row[40];
        const phf_day = row[41];
        const pba_day = row[42];
        const p6x9_day = row[43];
        const p9x13_day = row[44];
        const p13x20_day = row[45];
        const gaslift_gas_day = row[46];
        const oil_loss_ton = row[52];
        const downtime_category = row[53];
        const production_sub_skins_activity_id =
          production_sub_skins_activities.find(
            (i) => i.name.slice(0, 5).trim() === row[56]?.slice(0, 5).trim()
          )?.id;
        const comments = row[57];

        // check if some must-have cells are empty
        const must_have_datalist = [
          ['well_stock_category', well_stock_category_id],
          ['well_stock_sub_category', well_stock_sub_category_id],
          ['choke_wt', choke_wt],
          ['pqa_wt', pqa_wt],
          ['phf_wt', phf_wt],
          ['pba_wt', pba_wt],
          ['p6x9_wt', p6x9_wt],
          ['p9x13_wt', p9x13_wt],
          ['p13x20_wt', p13x20_wt],
          ['liquid_ton', liquid_ton],
          ['oil_density', oil_density],
          ['total_gas', total_gas],
          ['gaslift_gas_wt', gaslift_gas_wt],
          ['water_cut', water_cut],
          ['mechanical_impurities', mechanical_impurities],
          ['well_uptime_hours', well_uptime_hours],
          ['choke_day', choke_day],
          ['pqa_day', pqa_day],
          ['phf_day', phf_day],
          ['pba_day', pba_day],
          ['p6x9_day', p6x9_day],
          ['p9x13_day', p9x13_day],
          ['p13x20_day', p13x20_day],
          ['gaslift_gas_day', gaslift_gas_day],
          ['oil_loss_ton', oil_loss_ton],
        ];

        const error_datalist = must_have_datalist
          .filter(
            (i) => i[1] === null || i[1] === undefined || i[1]?.trim?.() === ''
          )
          .map((j) => j[0]);

        if (error_datalist.length > 0) {
          logger.log(`Check '${error_datalist.join(',  ')}'`, error);
          validation_error = true;
        }
        //

        // check if well is flowing, then flowmeter column is specified
        if (
          (well_stock_category_id === 1 || well_stock_category_id === 2) &&
          production_well_stock_sub_category_id === 1 &&
          !flowmeter
        ) {
          logger.log(`Check 'which flowmeter well is flowing'`, error);
          validation_error = true;
        }
        //

        // check if well_uptime_hours is in correct format
        if (well_uptime_hours < 0 || well_uptime_hours > 24) {
          logger.log(
            `Check 'well_uptime_hours should be between (0-24) hours'`,
            error
          );
          validation_error = true;
        }
        //

        // check if well_uptime_hours less than 24, reasons are specified
        if (
          well_uptime_hours < 24 &&
          (!downtime_category || !production_sub_skins_activity_id || !comments)
        ) {
          logger.log(
            `Check 'well_uptime_hours < 24, bu no skin, no comment'`,
            error
          );
          validation_error = true;
        }
        //

        // check liquid_ton is not out of range
        if (
          (well_stock_category_id === 1 || well_stock_category_id === 2) &&
          liquid_ton > 500
        ) {
          logger.log(`Check 'liquid_ton can not be bigger than 500'`, error);
          validation_error = true;
        }
        //

        // check total_gas is bigger than gaslift_gas
        if (
          total_gas < gaslift_gas_wt
          // || (total_gas / 24) * well_uptime_hours < gaslift_gas_day
        ) {
          logger.log(
            `Check 'total gas can not be less than gaslift gas'`,
            error
          );
          validation_error = true;
        }
        //

        // check water_cut and mechanical_impurities is not out of range
        if (
          water_cut < 0 ||
          water_cut > 100 ||
          mechanical_impurities < 0 ||
          mechanical_impurities > 100
        ) {
          logger.log(
            `Check 'water cut / mechanical impurities should be between (0-100)%'`,
            error
          );
          validation_error = true;
        }
        //

        // check whether last_lab_date belongs to well_test
        // const well_tests_first_entry_query =
        //   'SELECT TOP 1 * FROM well_tests WHERE well_id = @well_id ORDER BY well_test_date';

        // const {recordset: well_tests_first_entry_query_result} = await pool.request().input('well_id', well_id).query(well_tests_first_entry_query);

        // const { well_test_date: well_tests_first_entry_report_date } =
        //   well_tests_first_entry_query_result[0] || {};

        // if (well_tests_first_entry_report_date) {
        //   const lab_result_exists_query =
        //     'SELECT COUNT(*) AS well_tests_count FROM well_tests WHERE well_id = @well_id AND (well_test_date = @last_lab_date OR (DATEDIFF(day, @last_well_test_date, @last_lab_date) BETWEEN 0 AND 1) OR @last_lab_date < @well_tests_first_entry_report_date)';

        // const { recordset: lab_result_exists_query_result } = await pool
        //   .request()
        //   .input('well_id', well_id)
        //   .input('last_lab_date', last_lab_date)
        //   .input('last_well_test_date', last_well_test_date)
        //   .input(
        //     'well_tests_first_entry_report_date',
        //     well_tests_first_entry_report_date
        //   )
        //   .query(lab_result_exists_query);

        //   const { well_tests_count } = lab_result_exists_query_result[0] || {};

        //   if (!Number(well_tests_count)) {
        //     logger.log(
        //       `last_lab_date does not belong to past well_tests`,
        //       error
        //     );
        //     validation_error = true;
        //   }
        // }
        //

        // important, all errors rejects here
        if (validation_error) {
          logger.log(`Data is not persisted into DB!`, warning);
          continue inner;
        }
        //

        //// populate well_stock table
        // check well_stock entry exists in DB
        const well_stock_entry_exists_query =
          'SELECT COUNT(*) AS well_stock_entry_exists FROM well_stock WHERE well_id = @well_id AND report_date_id = @report_date_id';

        const { recordset: well_stock_entry_exists_query_result } = await pool
          .request()
          .input('well_id', well_id)
          .input('report_date_id', report_date_id)
          .query(well_stock_entry_exists_query);

        const { well_stock_entry_exists } =
          well_stock_entry_exists_query_result[0] || {};
        //

        // get previous entry from well_stock table
        const well_stock_previous_entry_query =
          'SELECT TOP 1 * FROM well_stock WHERE well_id = @well_id AND report_date_id < @report_date_id ORDER BY report_date_id DESC';

        const { recordset: well_stock_previous_entry_query_result } = await pool
          .request()
          .input('well_id', well_id)
          .input('report_date_id', report_date_id)
          .query(well_stock_previous_entry_query);

        const {
          well_stock_category_id:
            well_stock_previous_entry_well_stock_category_id,
          well_stock_sub_category_id:
            well_stock_previous_entry_well_stock_sub_category_id,
          production_well_stock_sub_category_id:
            well_stock_previous_entry_production_well_stock_sub_category_id,
          production_method_id: well_stock_previous_entry_production_method_id,
        } = well_stock_previous_entry_query_result[0] || {};
        //

        // insert entry into well_stock table
        const well_stock_insert_query =
          'INSERT INTO well_stock (well_id, report_date_id, well_stock_category_id, well_stock_sub_category_id, production_well_stock_sub_category_id, production_method_id) VALUES (@well_id, @report_date_id, @well_stock_category_id, @well_stock_sub_category_id, @production_well_stock_sub_category_id, @production_method_id)';

        const well_stock_changed =
          well_stock_previous_entry_well_stock_category_id !=
            well_stock_category_id ||
          well_stock_previous_entry_well_stock_sub_category_id !=
            well_stock_sub_category_id ||
          well_stock_previous_entry_production_well_stock_sub_category_id !=
            production_well_stock_sub_category_id ||
          well_stock_previous_entry_production_method_id !=
            production_method_id;

        if (!Number(well_stock_entry_exists) && well_stock_changed) {
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .input('well_stock_category_id', well_stock_category_id)
            .input('well_stock_sub_category_id', well_stock_sub_category_id)
            .input(
              'production_well_stock_sub_category_id',
              production_well_stock_sub_category_id
            )
            .input('production_method_id', production_method_id)
            .query(well_stock_insert_query);
          logger.log(`|'well_stock'| Populated!`, success);
          well_stock_insertion_count++;
        } else {
          logger.log(
            `|'well_stock'| Already populated! (or nothing changed compared to yesterday)`
          );
        }
        //
        ////

        //// populate completions table
        // check completions entry exists in DB
        const completions_entry_exists_query =
          'SELECT COUNT(*) AS completions_entry_exists FROM completions WHERE well_id = @well_id AND report_date_id = @report_date_id';

        const { recordset: completions_entry_exists_query_result } = await pool
          .request()
          .input('well_id', well_id)
          .input('report_date_id', report_date_id)
          .query(completions_entry_exists_query);

        const { completions_entry_exists } =
          completions_entry_exists_query_result[0] || {};
        //

        // get previous entry from completion table
        const completions_previous_entry_query =
          'SELECT TOP 1 * FROM completions WHERE well_id = @well_id AND report_date_id < @report_date_id ORDER BY report_date_id DESC';

        const { recordset: completions_previous_entry_query_result } =
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .query(completions_previous_entry_query);

        const {
          horizon_id: completions_previous_entry_horizon_id,
          casing: completions_previous_entry_casing,
          completion_interval: completions_previous_entry_completion_interval,
          tubing1_depth: completions_previous_entry_tubing1_depth,
          tubing1_length: completions_previous_entry_tubing1_length,
          tubing2_depth: completions_previous_entry_tubing2_depth,
          tubing2_length: completions_previous_entry_tubing2_length,
          tubing3_depth: completions_previous_entry_tubing3_depth,
          tubing3_length: completions_previous_entry_tubing3_length,
          packer_depth: completions_previous_entry_packer_depth,
        } = completions_previous_entry_query_result[0] || {};
        //

        // insert entry into completions table
        const completions_insert_query =
          'INSERT INTO completions (well_id, report_date_id, horizon_id, casing, completion_interval, tubing1_depth, tubing1_length, tubing2_depth, tubing2_length, tubing3_depth, tubing3_length, packer_depth) VALUES (@well_id, @report_date_id, @horizon_id, @casing, @completion_interval, @tubing1_depth, @tubing1_length, @tubing2_depth, @tubing2_length, @tubing3_depth, @tubing3_length, @packer_depth)';

        const completion_changed =
          completions_previous_entry_horizon_id != horizon_id ||
          completions_previous_entry_casing != casing ||
          completions_previous_entry_completion_interval !=
            completion_interval ||
          completions_previous_entry_tubing1_depth != tubing1_depth ||
          completions_previous_entry_tubing1_length != tubing1_length ||
          completions_previous_entry_tubing2_depth != tubing2_depth ||
          completions_previous_entry_tubing2_length != tubing2_length ||
          completions_previous_entry_tubing3_depth != tubing3_depth ||
          completions_previous_entry_tubing3_length != tubing3_length ||
          completions_previous_entry_packer_depth != packer_depth;

        if (!Number(completions_entry_exists) && completion_changed) {
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .input('horizon_id', horizon_id)
            .input('casing', casing)
            .input('completion_interval', completion_interval)
            .input('tubing1_depth', tubing1_depth)
            .input('tubing1_length', tubing1_length)
            .input('tubing2_depth', tubing2_depth)
            .input('tubing2_length', tubing2_length)
            .input('tubing3_depth', tubing3_depth)
            .input('tubing3_length', tubing3_length)
            .input('packer_depth', packer_depth)
            .query(completions_insert_query);
          logger.log(`|'completions'| Populated!`, success);
          completion_insertion_count++;
        } else {
          logger.log(
            `|'completions'| Already populated! (or nothing changed compared to yesterday)`
          );
        }
        //
        ////

        //// populate well_downtime_reasons table
        // check well_downtime_reasons entry exists in DB
        const well_downtime_reasons_entry_exists_query =
          'SELECT COUNT(*) AS well_downtime_reasons_entry_exists FROM well_downtime_reasons WHERE well_id = @well_id AND report_date_id = @report_date_id';

        const { recordset: well_downtime_reasons_entry_exists_query_result } =
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .query(well_downtime_reasons_entry_exists_query);

        const { well_downtime_reasons_entry_exists } =
          well_downtime_reasons_entry_exists_query_result[0] || {};
        //

        // get previous entry from well_downtime_reasons table
        const well_downtime_reasons_previous_entry_query =
          'SELECT TOP 1 * FROM well_downtime_reasons WHERE well_id = @well_id AND report_date_id < @report_date_id ORDER BY report_date_id DESC';

        const { recordset: well_downtime_reasons_previous_entry_query_result } =
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .query(well_downtime_reasons_previous_entry_query);

        const {
          downtime_category: well_downtime_reasons_previous_downtime_category,
          production_sub_skins_activity_id:
            well_downtime_reasons_previous_production_sub_skins_activity_id,
          comments: well_downtime_reasons_previous_comments,
        } = well_downtime_reasons_previous_entry_query_result[0] || {};
        //

        // insert entry into well_downtime_reasons table
        const well_downtime_reasons_insert_query =
          'INSERT INTO well_downtime_reasons (well_id, report_date_id, downtime_category, production_sub_skins_activity_id, comments) VALUES (@well_id, @report_date_id, @downtime_category, @production_sub_skins_activity_id, @comments)';

        const well_downtime_reasons_changed =
          well_downtime_reasons_previous_downtime_category !=
            downtime_category ||
          well_downtime_reasons_previous_production_sub_skins_activity_id !=
            production_sub_skins_activity_id ||
          well_downtime_reasons_previous_comments != comments;

        if (
          !Number(well_downtime_reasons_entry_exists) &&
          well_downtime_reasons_changed
        ) {
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .input('downtime_category', downtime_category)
            .input(
              'production_sub_skins_activity_id',
              production_sub_skins_activity_id
            )
            .input('comments', comments)
            .query(well_downtime_reasons_insert_query);
          logger.log(`|'well_downtime_reasons'| Populated!`, success);
          well_downtime_reasons_insertion_count++;
        } else {
          logger.log(
            `|'well_downtime_reasons'| Already populated! (or well_uptime_hours = 24)`
          );
        }
        //
        ////

        //// populate daily_well_parameters table
        // check daily_well_parameters entry exists in DB
        const daily_well_parameters_entry_exists_query =
          'SELECT COUNT(*) AS daily_well_parameters_entry_exists FROM daily_well_parameters WHERE well_id = @well_id AND report_date_id = @report_date_id';

        const { recordset: daily_well_parameters_entry_exists_query_result } =
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .query(daily_well_parameters_entry_exists_query);

        const { daily_well_parameters_entry_exists } =
          daily_well_parameters_entry_exists_query_result[0] || {};
        //

        // insert entry into daily_well_parameters table
        const daily_well_parameters_insert_query =
          'INSERT INTO daily_well_parameters (well_id, report_date_id, flowmeter, well_uptime_hours, choke, pqa, phf, pba, p6x9, p9x13, p13x20, liquid_ton, total_gas, gaslift_gas, reported_water_cut, water_cut, mechanical_impurities, oil_density, oil_loss_ton) VALUES (@well_id, @report_date_id, @flowmeter, @well_uptime_hours, @choke_day, @pqa_day, @phf_day, @pba_day, @p6x9_day, @p9x13_day, @p13x20_day, @liquid_ton, @total_gas, @gaslift_gas, @reported_water_cut, @water_cut, @mechanical_impurities, @oil_density, @oil_loss_ton)';

        if (!Number(daily_well_parameters_entry_exists)) {
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .input('flowmeter', flowmeter)
            .input('well_uptime_hours', well_uptime_hours)
            .input('choke_day', choke_day)
            .input('pqa_day', pqa_day)
            .input('phf_day', phf_day)
            .input('pba_day', pba_day)
            .input('p6x9_day', p6x9_day)
            .input('p9x13_day', p9x13_day)
            .input('p13x20_day', p13x20_day)
            .input('liquid_ton', (liquid_ton / 24) * well_uptime_hours)
            .input('total_gas', (total_gas / 24) * well_uptime_hours)
            .input('gaslift_gas', (gaslift_gas_day / 24) * well_uptime_hours)
            .input('reported_water_cut', water_cut)
            .input('water_cut', water_cut)
            .input('mechanical_impurities', mechanical_impurities)
            .input('oil_density', oil_density)
            .input(
              'oil_loss_ton',
              oil_density == 0 && water_cut == 0
                ? 0
                : ((liquid_ton / 24) *
                    (24 - well_uptime_hours) *
                    (1 - water_cut / 100) *
                    oil_density) /
                    (oil_density * (1 - water_cut / 100) + water_cut / 100)
            )
            .query(daily_well_parameters_insert_query);
          logger.log(`|'daily_well_parameters'| Populated!`, success);
          daily_well_parameters_insertion_count++;
        } else {
          logger.log(`|'daily_well_parameters'| Already populated!`);
        }
        //
        ////

        //// populate well_tests table
        // check well_tests entry exists in DB
        const well_tests_entry_exists_query =
          'SELECT COUNT(*) AS well_tests_entry_exists FROM well_tests WHERE well_id = @well_id AND well_test_date = @last_well_test_date';

        const { recordset: well_tests_entry_exists_query_result } = await pool
          .request()
          .input('well_id', well_id)
          .input('last_well_test_date', last_well_test_date)
          .query(well_tests_entry_exists_query);

        const { well_tests_entry_exists } =
          well_tests_entry_exists_query_result[0] || {};
        //

        // insert entry into well_tests table
        const well_tests_insert_query =
          'INSERT INTO well_tests (well_id, report_date_id, well_test_date, choke, pqa, phf, pba, p6x9, p9x13, p13x20, liquid_ton, total_gas, gaslift_gas, reported_water_cut, water_cut, mechanical_impurities, oil_density) VALUES (@well_id, @report_date_id, @well_test_date, @choke, @pqa, @phf, @pba, @p6x9, @p9x13, @p13x20, @liquid_ton, @total_gas, @gaslift_gas, @reported_water_cut, @water_cut, @mechanical_impurities, @oil_density)';

        if (!Number(well_tests_entry_exists)) {
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .input('well_test_date', last_well_test_date)
            .input('choke', choke_wt)
            .input('pqa', pqa_wt)
            .input('phf', phf_wt)
            .input('pba', pba_wt)
            .input('p6x9', p6x9_wt)
            .input('p9x13', p9x13_wt)
            .input('p13x20', p13x20_wt)
            .input('liquid_ton', liquid_ton)
            .input('total_gas', total_gas)
            .input('gaslift_gas', gaslift_gas_wt)
            .input('reported_water_cut', water_cut)
            .input('water_cut', water_cut)
            .input('mechanical_impurities', mechanical_impurities)
            .input('oil_density', oil_density)
            .query(well_tests_insert_query);
          logger.log(`|'well_tests'| Populated!`, success);
          well_tests_insertion_count++;
        } else {
          logger.log(`|'well_tests'| Already populated!`);
        }
        //
        ////

        //// populate laboratory_results table
        // check laboratory_results entry exists in DB
        const laboratory_results_entry_exists_query =
          'SELECT COUNT(*) AS laboratory_results_entry_exists FROM laboratory_results WHERE well_id = @well_id AND last_lab_date = @last_lab_date';

        const { recordset: laboratory_results_entry_exists_query_result } =
          await pool
            .request()
            .input('well_id', well_id)
            .input('last_lab_date', last_lab_date)
            .query(laboratory_results_entry_exists_query);

        const { laboratory_results_entry_exists } =
          laboratory_results_entry_exists_query_result[0] || {};
        //

        // insert entry into laboratory_results table
        const laboratory_results_insert_query =
          'INSERT INTO laboratory_results (well_id, report_date_id, last_lab_date, water_cut, mechanical_impurities) VALUES (@well_id, @report_date_id, @last_lab_date, @water_cut, @mechanical_impurities)';

        if (!Number(laboratory_results_entry_exists)) {
          await pool
            .request()
            .input('well_id', well_id)
            .input('report_date_id', report_date_id)
            .input('last_lab_date', last_lab_date)
            .input('water_cut', water_cut)
            .input('mechanical_impurities', mechanical_impurities)
            .query(laboratory_results_insert_query);
          logger.log(`|'laboratory_results'| Populated!`, success);

          laboratory_results_insertion_count++;
        } else {
          logger.log(`|'laboratory_results'| Already populated!`);
        }
        //
        ////

        // check whether well_test_date or last_lab_date is older than 15 days in producing wells
        if (
          production_well_stock_sub_category_id == 1 &&
          ((new Date(report_date) - new Date(last_well_test_date)) / 86400000 >
            15 ||
            (new Date(report_date) - new Date(last_lab_date)) / 86400000 > 15)
        ) {
          logger.log(
            `Well test or lab results are too old for producing well`,
            warning
          );
        }
        //

        // check whether last_lab_date is obsolete
        // if (
        //   (new Date(report_date) - new Date(last_well_test_date)) / 86400000 >=
        //     7 &&
        //   last_well_test_date != last_lab_date
        // ) {
        //   logger.log(
        //     `Update lab results! Well test result should be available!`,
        //     warning
        //   );
        // }
        //

        // check whether lab results of well tests are present
        // const well_test_lab_result_not_exist_query =
        //   'SELECT TOP 10 well_test_date FROM well_tests AS wt ' +
        //   'WHERE well_id = @well_id ' +
        //   'AND (SELECT COUNT(*) = 0 FROM laboratory_results AS lr WHERE well_id = @well_id AND (DATEDIFF(day, wt.well_test_date, lr.last_lab_date) BETWEEN 0 AND 1)) ' +
        //   'AND DATEDIFF(day, CAST(GETDATE() AS DATE), wt.well_test_date) >= 7 ' +
        //   'ORDER BY wt.well_test_date DESC ';

        // const {recordset: well_test_lab_result_not_exist_list} = await pool
        //   .request()
        //   .input('well_id', well_id)
        //   .query(well_test_lab_result_not_exist_query);

        // if (well_test_lab_result_not_exist_list.length > 0) {
        //   const well_test_lab_result_not_exist_string =
        //     well_test_lab_result_not_exist_list
        //       .map((i) => i.well_test_date)
        //       .join(', ');
        //   logger.log(
        //     `Lab results of these well tests do not exist: ${well_test_lab_result_not_exist_string}`,
        //     warning
        //   );
        // }
        //
      }
      ////
    }
  }
  ////
} catch (err) {
  logger.log(err, error);
  console.log('Database error:', err);
} finally {
  if (pool) {
    await pool.close();
  }
  logger_without_timestamp = true;
  logger.log(`${'='.repeat(100)}`);
  logger.log('SCRIPT EXECUTION FINISHED!');
  logger.log(`${'.'.repeat(100)}`);
  logger.log(`S U M M A R Y`);
  logger.log(`${success_count.toString().padStart(6)}\t\tsuccess`);
  logger.log(`${error_count.toString().padStart(6)}\t\terror`);
  logger.log(`${warning_count.toString().padStart(6)}\t\twarning`);
  logger.log(`${info_count.toString().padStart(6)}\t\tinfo`);
  logger.log(
    `\n${flowmeter_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'flowmeters'|`
  );
  logger.log(
    `${well_stock_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'well_stock'|`
  );
  logger.log(
    `${completion_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'completions'|`
  );
  logger.log(
    `${well_tests_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'well_tests'|`
  );
  logger.log(
    `${daily_well_parameters_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'daily_well_parameters'|`
  );
  logger.log(
    `${well_downtime_reasons_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'well_downtime_reasons'|`
  );
  logger.log(
    `${laboratory_results_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'laboratory_results'|`
  );
  logger.log(`${'.'.repeat(100)}`);
  logger.log(`${'*'.repeat(100)}`);
  logger_without_timestamp = false;
}

function getFormattedFilename() {
  const now = new Date();
  const day = String(now.getDate()).padStart(2, '0');
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const year = now.getFullYear();

  return `./logs/${day}.${month}.${year}-dpr.log`;
}

//// when we insert into mysql date needs to be in specific format
function convertDateToMSsqlFormat(date) {
  const formattedDate = date
    .toLocaleString('en-US', {
      timeZone: 'Asia/Baku',
      hour12: false,
    })
    .split(',')[0];
  const [month, day, year] = formattedDate.split('/');
  const mysqlDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
  return mysqlDate;
}

//// sometimes we get date value as number (timestamp) when parsing excel file
function processDateValue(value) {
  if (typeof value === 'number') {
    const excelEpoch = new Date(Date.UTC(1899, 11, 30));
    const date = new Date(excelEpoch.getTime() + value * 86400000);
    return convertDateToMSsqlFormat(
      new Date(
        Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())
      )
    );
  } else if (typeof value === 'object' || value instanceof Date) {
    return convertDateToMSsqlFormat(value);
  }
  return convertDateToMSsqlFormat(value);
}

function isValidDate(value) {
  if (typeof value === 'number') {
    if (value >= 0 && value < 100) return true;
    return value > 18000;
  }
  return !isNaN(Date.parse(value));
}

function isYesterday(date1_id, date2_id) {
  return date1_id - date2_id == 1;
}
