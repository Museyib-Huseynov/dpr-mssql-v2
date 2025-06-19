import {
  promises as fs,
  createWriteStream,
  existsSync,
  mkdirSync,
  rmSync,
} from 'fs';
import path from 'path';
import mssql from 'mssql';
import officeCrypto from 'officecrypto-tool';
import readXlsxFile from 'read-excel-file/node';

const inputFolder = process.argv[2] || './';
const password = 'nd123';

//// generate logger function to log to console and local file
if (!existsSync('./logs')) {
  mkdirSync('./logs', { recursive: true });
}

if (existsSync('./QC')) {
  rmSync('./QC', { recursive: true, force: true });
}
mkdirSync('./QC', { recursive: true });

const logFilePath = getFormattedFilename('logs');
const QCFilePath = getFormattedFilename('QC');

const logStream = createWriteStream(logFilePath, { flags: 'a' });
const QCStream = createWriteStream(QCFilePath, { flags: 'a' });

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
let gas_well_tests_insertion_count = 0;
let daily_well_parameters_insertion_count = 0;
let well_downtime_reasons_insertion_count = 0;
let laboratory_results_insertion_count = 0;
let daily_general_comments_insertion_count = 0;

const logger = {
  log: (
    message,
    level = 'INFO',
    logger_without_timestamp_and_level = false,
    QC = false
  ) => {
    const timestamp = new Date().toLocaleString('en-US', {
      timeZone: 'Asia/Baku',
      hour12: false,
    });

    if (level === success) {
      success_count++;
    } else if (level === error) {
      error_count++;
    } else if (level === warning) {
      warning_count++;
    } else if (
      level === 'INFO' &&
      logger_without_timestamp_and_level === false
    ) {
      info_count++;
    }

    let content;
    if (logger_without_timestamp_and_level) {
      content = `\n${message}`;
    } else {
      content = `\n${timestamp} ${`[${level}]:`.padStart(10)} ${message}`;
    }

    logStream.write(content);
    console.log(content);

    if (QC == true) {
      QCStream.write(content);
    }
  },
  close: () => {
    logStream.end();
    QCStream.end();
  },
};
////

let pool;
try {
  logger.log(`${'*'.repeat(100)}`, 'INFO', true);
  logger.log('SCRIPT EXECUTION STARTED...', 'INFO', true);

  pool = await mssql.connect(
    'Server=localhost,1433;Database=dpr_11;User Id=museyib;Password=3231292;Encrypt=false'
  );

  const { recordset: fields } = await pool
    .request()
    .query('SELECT * FROM fields');
  const { recordset: platforms } = await pool
    .request()
    .query('SELECT * FROM platforms');
  const { recordset: wells } = await pool
    .request()
    .query('SELECT * FROM wells');
  const { recordset: well_stock_categories } = await pool
    .request()
    .query('SELECT * FROM well_stock_categories');
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

  async function processFiles(folder) {
    //// Go through files in folder specified in `folder`, find `.xls` or `xlsx` files, decrypt them, parse each cell from Excel files, insert into db
    const files = await fs.readdir(folder, { withFileTypes: true });

    outer: for (const file of files) {
      const filePath = path.join(folder, file.name);
      if (file.isDirectory()) {
        await processFiles(filePath);
      } else {
        const extension = path.extname(file.name).toLowerCase();
        if (extension === '.xls' || extension === '.xlsx') {
          logger.log(`${'='.repeat(100)}`, 'INFO', true);
          logger.log(`|'${filePath}'| Parsing...`, 'INFO', true, true);

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

          // parse field_id
          const field = rows[3][5];
          const field_id = fields.find((i) => i.name == field)?.id;
          if (!field_id) {
            logger.log(
              'Field name is not correct in excel file',
              error,
              false,
              true
            );
            logger.log(`Data is not persisted into DB!`, warning);
            continue outer;
          }
          //

          // parse platform_id
          const platform = rows[4][5];
          const platform_id = platforms.find((i) => i.name == platform)?.id;
          if (!platform_id) {
            logger.log(
              `Platform number is not correct in excel file`,
              error,
              false,
              true
            );
            logger.log(`Data is not persisted into DB!`, warning);
            continue outer;
          }
          //

          // parse report_date
          let report_date = rows[6][5];
          if (!isValidDate(report_date)) {
            logger.log(`Report_date is not correct`, error, false, true);
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

          // check if report is yesterday's report
          // const today = new Date().toLocaleDateString('en-CA', {
          //   timeZone: 'Asia/Baku',
          // });
          // const diffDays = (new Date(today) - new Date(report_date)) / 86400000;
          // if (diffDays !== 1) {
          //   logger.log(`Report_date is not yesterday's`, error, false, true);
          //   logger.log(`Data is not persisted into DB!`, warning);
          //   continue outer;
          // }
          //

          QC: for (let i = 14; i < rows.length; i++) {
            const row = rows[i];
            if (row[2] === null) {
              let errors = [
                rows[i + 7][6],
                rows[i + 8][6],
                rows[i + 9][6],
                rows[i + 10][6],
                rows[i + 11][6],
                rows[i + 12][6],
                rows[i + 13][6],
                rows[i + 14][6],
                rows[i + 15][6],
                rows[i + 16][6],
                rows[i + 17][6],
                rows[i + 18][6],
                rows[i + 19][6],
                rows[i + 20][6],
                rows[i + 21][6],
                rows[i + 22][6],
              ];

              errors = errors.map((i) => {
                return Boolean(i);
              });

              if (errors.includes(true)) {
                logger.log(
                  `There is an error in ${field} field - platform ${platform}`,
                  error,
                  false,
                  true
                );
                break outer;
              }
              break QC;
            }
          }

          // rename excel file to keep it clean
          const newFileName = `DPR-${platform}-${report_date}.xlsx`;
          const newFilePath = path.join(path.dirname(filePath), newFileName);
          await fs.rename(filePath, newFilePath);
          //

          // parse responsible_person
          let responsible_person = rows[3][18];
          //

          // parse phone_number
          let phone_number = rows[4][18];
          //

          // parse flowmeter params
          const reading1 = rows[3][62];
          const reading2 = rows[4][62];
          const reading3 = rows[3][63];
          const reading4 = rows[4][63];
          let calibration_date = rows[6][63];
          if (isValidDate(calibration_date)) {
            calibration_date = processDateValue(calibration_date);
          } else {
            calibration_date = null;
          }
          //

          //// populate flowmeters table
          logger.log(`${'-'.repeat(100)}`, 'INFO', true);
          logger.log(
            `|'Report Date: ${report_date}'|'Platform ${platform}'|'flowmeters table'| populating DB...`,
            'INFO',
            true
          );

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

          const { recordset: flowmeters_previous_entry_query_result } =
            await pool
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

          // insert entry into flowmeter table
          const flowmeters_insert_query =
            'INSERT INTO flowmeters (platform_id, report_date_id, reading1, reading2, reading3, reading4, calibration_date) VALUES (@platform_id, @report_date_id, @reading1, @reading2, @reading3, @reading4, @calibration_date)';

          if (field_id == 1) {
            if (![2, 3, 4, 7, 8, 13].includes(platform)) {
              logger.log(`Flowmeter is not present`);
              logger.log(`Not populated!`);
            } else if (
              reading2 == null ||
              reading4 == null ||
              ([8, 13].includes(platform) &&
                (reading1 == null || reading3 == null))
            ) {
              logger.log(`Check flowmeter parameters`, error, false, true);
              logger.log(`Not populated!`, warning);
            } else if (
              flowmeters_previous_entry_is_yesterday &&
              [8, 13].includes(platform) &&
              (flowmeters_previous_entry_reading2 != reading1 ||
                flowmeters_previous_entry_reading4 != reading3)
            ) {
              logger.log(
                `Yesterday's flowmeter reading should be same with yesterday's, but different!`,
                error,
                false,
                true
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
                [2, 3, 4, 7].includes(platform) &&
                (flowmeters_previous_entry_reading2 == reading2 ||
                  flowmeters_previous_entry_reading4 == reading4)
              ) {
                logger.log(
                  `Today's Flowmeter params are same as yesterday's!`,
                  warning,
                  false,
                  true
                );
              }
              //
            } else {
              logger.log(`Already populated!`);
            }
          } else {
            logger.log(`Flowmeter is not present`);
            logger.log(`Not populated!`);
          }

          //
          ////

          //// looping through rows (wells)
          inner: for (let i = 14; i < rows.length; i++) {
            logger.log(`${'-'.repeat(100)}`, 'INFO', true);
            const row = rows[i];

            if (row[2] === null) {
              let general_comments = rows[i + 7][26];

              //// populate daily_general_comments table
              // check daily_general_comments entry exists in DB
              const daily_general_comments_entry_exists_query =
                'SELECT COUNT(*) AS daily_general_comments_entry_exists FROM daily_general_comments WHERE field_id=@field_id AND report_date_id=@report_date_id AND platform=@platform';

              const {
                recordset: daily_general_comments_entry_exists_query_result,
              } = await pool
                .request()
                .input('field_id', field_id)
                .input('report_date_id', report_date_id)
                .input('platform', platform)
                .query(daily_general_comments_entry_exists_query);

              const { daily_general_comments_entry_exists } =
                daily_general_comments_entry_exists_query_result[0] || {};
              //

              // get previous entry from daily_general_comments
              const daily_general_comments_previous_entry_query =
                'SELECT TOP 1 * FROM daily_general_comments WHERE field_id = @field_id AND platform = @platform AND report_date_id < @report_date_id ORDER BY report_date_id DESC';

              const {
                recordset: daily_general_comments_previous_entry_query_result,
              } = await pool
                .request()
                .input('field_id', field_id)
                .input('platform', platform)
                .input('report_date_id', report_date_id)
                .query(daily_general_comments_previous_entry_query);

              const {
                general_comments:
                  daily_general_comments_previous_entry_general_comments,
              } = daily_general_comments_previous_entry_query_result[0] || {};

              const general_comment_changed =
                daily_general_comments_previous_entry_general_comments !=
                general_comments;
              //

              // insert entry into daily_general_comments table
              const daily_general_comments_insert_query =
                'INSERT INTO daily_general_comments (report_date_id, field_id, platform, general_comments) VALUES (@report_date_id, @field_id, @platform, @general_comments)';

              if (
                !Number(daily_general_comments_entry_exists) &&
                general_comment_changed
              ) {
                await pool
                  .request()
                  .input('report_date_id', report_date_id)
                  .input('field_id', field_id)
                  .input('platform', platform)
                  .input('general_comments', general_comments)
                  .query(daily_general_comments_insert_query);
                logger.log(`|'daily_general_comments'| Populated!`, success);
                daily_general_comments_insertion_count++;
              } else {
                logger.log(`|'daily_general_comments'| Already populated!`);
              }
              //
              ////
              break;
            }

            let validation_error = false;

            const well_number = row[4];
            const well_id = wells.find(
              (i) => i.name.trim() == String(well_number).trim()
            )?.id;

            // check if well name is specified correctly
            if (!well_id) {
              logger.log(
                `Check |'Platform ${platform}'|'row-${
                  i + 1
                }'| Well name is not correct`,
                error,
                false,
                true
              );
              logger.log(
                `Check |'Platform ${platform}'|'row-${
                  i + 1
                }'| Data is not persisted into DB!`,
                warning
              );
              continue inner;
            }
            //

            logger.log(
              `|'Report Date: ${report_date}'|'Platform ${platform}'|'Well ${well_number}'| populating DB...`,
              'INFO',
              true
            );

            const well_stock_category_id = well_stock_categories.find(
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
            let last_gas_well_test_date = row[23];
            let last_lab_date = row[26];

            // check if dates are in correct format
            if (
              !isValidDate(last_well_test_date) ||
              !isValidDate(last_gas_well_test_date) ||
              !isValidDate(last_lab_date)
            ) {
              logger.log(
                `Check 'last_well_test_date or last_lab_date is not correct'`,
                error,
                false,
                true
              );
              validation_error = true;
            } else {
              last_well_test_date = processDateValue(last_well_test_date);
              last_gas_well_test_date = processDateValue(
                last_gas_well_test_date
              );
              last_lab_date = processDateValue(last_lab_date);
            }
            //

            const liquid_ton = row[20];
            const oil_ton = row[21];
            const water_ton = row[22];
            const total_gas = row[24];
            const gaslift_gas_wt = row[25];
            const water_cut = row[27];
            const mechanical_impurities = row[28];
            const pqa = row[29];
            const phf = row[30];
            const pba = row[31];
            const p6x9 = row[32];
            const p9x13 = row[33];
            const p13x20 = row[34];
            const choke = row[35];
            const gaslift_gas_day = row[36];
            const gaslift_system_pressure = row[37];
            const pump_depth = row[38];
            const pump_frequency = row[39];
            const pump_hydrostatic_pressure = row[40];
            const esp_pump_size = row[41];
            const esp_pump_stages = row[42];
            const esp_pump_rate = row[43];
            const esp_pump_head = row[44];
            const esp_downhole_gas_separator = row[45];
            const srp_pumpjack_type = row[46];
            const srp_pump_plunger_diameter = row[47];
            const srp_plunger_stroke_length = row[48];
            const srp_balancer_oscillation_frequency = row[49];
            const srp_pump_rate_coefficient = row[50];
            const srp_max_motor_speed = row[51];
            const srp_shaft_diameter = row[52];
            const pcp_pump_rate = row[53];
            const pcp_rpm = row[54];
            const pcp_screw_diameter = row[55];
            const static_fluid_level = row[56];
            const dynamic_fluid_level = row[57];
            const well_uptime_hours = row[58];
            const downtime_category = row[59];
            const production_sub_skins_activity_id =
              production_sub_skins_activities.find(
                (i) => i.name.slice(0, 5).trim() === row[62]?.slice(0, 5).trim()
              )?.id;
            const comments = row[63];

            // check if well is flowing, then flowmeter column is specified
            if (
              field_id === 1 &&
              (well_stock_category_id === 1 || well_stock_category_id === 2) &&
              production_well_stock_sub_category_id === 1 &&
              !flowmeter
            ) {
              logger.log(
                `Check 'which flowmeter well is flowing'`,
                error,
                false,
                true
              );
              validation_error = true;
            }
            //

            // check if well_uptime_hours is in correct format
            if (well_uptime_hours < 0 || well_uptime_hours > 24) {
              logger.log(
                `Check 'well_uptime_hours should be between (0-24) hours'`,
                error,
                false,
                true
              );
              validation_error = true;
            }
            //

            // check if well_uptime_hours less than 24, reasons are specified
            if (
              well_uptime_hours < 24 &&
              (!downtime_category ||
                !production_sub_skins_activity_id ||
                !comments)
            ) {
              logger.log(
                `Check 'well_uptime_hours < 24, bu no skin, no comment'`,
                error,
                false,
                true
              );
              validation_error = true;
            }
            //

            // check liquid_ton is not out of range
            if (
              (well_stock_category_id === 1 || well_stock_category_id === 2) &&
              liquid_ton > 500
            ) {
              logger.log(
                `Check 'liquid_ton can not be bigger than 500'`,
                error,
                false,
                true
              );
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
                error,
                false,
                true
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
                error,
                false,
                true
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

            const { recordset: well_stock_entry_exists_query_result } =
              await pool
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

            const { recordset: well_stock_previous_entry_query_result } =
              await pool
                .request()
                .input('well_id', well_id)
                .input('report_date_id', report_date_id)
                .query(well_stock_previous_entry_query);

            const {
              well_stock_category_id:
                well_stock_previous_entry_well_stock_category_id,
              production_well_stock_sub_category_id:
                well_stock_previous_entry_production_well_stock_sub_category_id,
              production_method_id:
                well_stock_previous_entry_production_method_id,
            } = well_stock_previous_entry_query_result[0] || {};
            //

            // insert entry into well_stock table
            const well_stock_insert_query =
              'INSERT INTO well_stock (well_id, report_date_id, well_stock_category_id, production_well_stock_sub_category_id, production_method_id) VALUES (@well_id, @report_date_id, @well_stock_category_id, @production_well_stock_sub_category_id, @production_method_id)';

            const well_stock_changed =
              well_stock_previous_entry_well_stock_category_id !=
                well_stock_category_id ||
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
                .input(
                  'production_well_stock_sub_category_id',
                  production_well_stock_sub_category_id
                )
                .input('production_method_id', production_method_id)
                .query(well_stock_insert_query);
              logger.log(
                `|'well_stock'| Populated! Change in well ${well_number}`,
                warning,
                false,
                true
              );
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

            const { recordset: completions_entry_exists_query_result } =
              await pool
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
              completion_interval:
                completions_previous_entry_completion_interval,
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
              logger.log(
                `|'completions'| Populated! Change in well ${well_number}`,
                warning,
                false,
                true
              );
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

            const {
              recordset: well_downtime_reasons_entry_exists_query_result,
            } = await pool
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

            const {
              recordset: well_downtime_reasons_previous_entry_query_result,
            } = await pool
              .request()
              .input('well_id', well_id)
              .input('report_date_id', report_date_id)
              .query(well_downtime_reasons_previous_entry_query);

            const {
              downtime_category:
                well_downtime_reasons_previous_downtime_category,
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
              logger.log(
                `|'well_downtime_reasons'| Populated! Change in well ${well_number}`,
                warning,
                false,
                true
              );
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

            const {
              recordset: daily_well_parameters_entry_exists_query_result,
            } = await pool
              .request()
              .input('well_id', well_id)
              .input('report_date_id', report_date_id)
              .query(daily_well_parameters_entry_exists_query);

            const { daily_well_parameters_entry_exists } =
              daily_well_parameters_entry_exists_query_result[0] || {};
            //

            // insert entry into daily_well_parameters table
            const daily_well_parameters_insert_query =
              'INSERT INTO daily_well_parameters (well_id, report_date_id, flowmeter, well_uptime_hours, choke, pqa, phf, pba, p6x9, p9x13, p13x20, gaslift_gas, pump_depth, pump_frequency, pump_hydrostatic_pressure, esp_pump_size, esp_pump_stages, esp_pump_rate, esp_pump_head, esp_downhole_gas_separator, srp_pumpjack_type, srp_pump_plunger_diameter, srp_plunger_stroke_length, srp_balancer_oscillation_frequency, srp_pump_rate_coefficient, srp_max_motor_speed, srp_shaft_diameter, pcp_pump_rate, pcp_rpm, pcp_screw_diameter, static_fluid_level, dynamic_fluid_level, responsible_person, phone_number) VALUES (@well_id, @report_date_id, @flowmeter, @well_uptime_hours, @choke, @pqa, @phf, @pba, @p6x9, @p9x13, @p13x20, @gaslift_gas, @pump_depth, @pump_frequency, @pump_hydrostatic_pressure, @esp_pump_size, @esp_pump_stages, @esp_pump_rate, @esp_pump_head, @esp_downhole_gas_separator, @srp_pumpjack_type, @srp_pump_plunger_diameter, @srp_plunger_stroke_length, @srp_balancer_oscillation_frequency, @srp_pump_rate_coefficient, @srp_max_motor_speed, @srp_shaft_diameter, @pcp_pump_rate, @pcp_rpm, @pcp_screw_diameter, @static_fluid_level, @dynamic_fluid_level, @responsible_person, @phone_number)';

            if (!Number(daily_well_parameters_entry_exists)) {
              await pool
                .request()
                .input('well_id', well_id)
                .input('report_date_id', report_date_id)
                .input('flowmeter', flowmeter)
                .input('well_uptime_hours', well_uptime_hours)
                .input('choke', choke)
                .input('pqa', pqa)
                .input('phf', phf)
                .input('pba', pba)
                .input('p6x9', p6x9)
                .input('p9x13', p9x13)
                .input('p13x20', p13x20)
                .input(
                  'gaslift_gas',
                  (gaslift_gas_day / 24) * well_uptime_hours
                )
                .input('pump_depth', pump_depth)
                .input('pump_frequency', pump_frequency)
                .input('pump_hydrostatic_pressure', pump_hydrostatic_pressure)
                .input('esp_pump_size', esp_pump_size)
                .input('esp_pump_stages', esp_pump_stages)
                .input('esp_pump_rate', esp_pump_rate)
                .input('esp_pump_head', esp_pump_head)
                .input('esp_downhole_gas_separator', esp_downhole_gas_separator)
                .input('srp_pumpjack_type', srp_pumpjack_type)
                .input('srp_pump_plunger_diameter', srp_pump_plunger_diameter)
                .input('srp_plunger_stroke_length', srp_plunger_stroke_length)
                .input(
                  'srp_balancer_oscillation_frequency',
                  srp_balancer_oscillation_frequency
                )
                .input('srp_pump_rate_coefficient', srp_pump_rate_coefficient)
                .input('srp_max_motor_speed', srp_max_motor_speed)
                .input('srp_shaft_diameter', srp_shaft_diameter)
                .input('pcp_pump_rate', pcp_pump_rate)
                .input('pcp_rpm', pcp_rpm)
                .input('pcp_screw_diameter', pcp_screw_diameter)
                .input('static_fluid_level', static_fluid_level)
                .input('dynamic_fluid_level', dynamic_fluid_level)
                .input('responsible_person', responsible_person)
                .input('phone_number', phone_number)
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

            const { recordset: well_tests_entry_exists_query_result } =
              await pool
                .request()
                .input('well_id', well_id)
                .input('last_well_test_date', last_well_test_date)
                .query(well_tests_entry_exists_query);

            const { well_tests_entry_exists } =
              well_tests_entry_exists_query_result[0] || {};
            //

            // insert entry into well_tests table
            const well_tests_insert_query =
              'INSERT INTO well_tests (well_id, report_date_id, well_test_date, liquid_ton, oil_ton, water_ton) VALUES (@well_id, @report_date_id, @well_test_date, @liquid_ton, @oil_ton, @water_ton)';

            if (!Number(well_tests_entry_exists)) {
              await pool
                .request()
                .input('well_id', well_id)
                .input('report_date_id', report_date_id)
                .input('well_test_date', last_well_test_date)
                .input('liquid_ton', liquid_ton)
                .input('oil_ton', oil_ton)
                .input('water_ton', water_ton)
                .query(well_tests_insert_query);
              logger.log(`|'well_tests'| Populated!`, success);
              well_tests_insertion_count++;
            } else {
              logger.log(`|'well_tests'| Already populated!`);
            }
            //
            ////

            //// populate gas_well_tests table
            // check gas_well_tests entry exists in DB
            const gas_well_tests_entry_exists_query =
              'SELECT COUNT(*) AS gas_well_tests_entry_exists FROM gas_well_tests WHERE well_id=@well_id AND well_test_date=@last_gas_well_test_date';

            const { recordset: gas_well_tests_entry_exists_query_result } =
              await pool
                .request()
                .input('well_id', well_id)
                .input('last_gas_well_test_date', last_gas_well_test_date)
                .query(gas_well_tests_entry_exists_query);

            const { gas_well_tests_entry_exists } =
              gas_well_tests_entry_exists_query_result[0] || {};
            //

            // insert entry into gas_well_tests table
            const gas_well_tests_insert_query =
              'INSERT INTO gas_well_tests (well_id, report_date_id, well_test_date, total_gas, gaslift_gas) VALUES (@well_id, @report_date_id, @last_gas_well_test_date, @total_gas, @gaslift_gas)';

            if (!Number(gas_well_tests_entry_exists)) {
              await pool
                .request()
                .input('well_id', well_id)
                .input('report_date_id', report_date_id)
                .input('last_gas_well_test_date', last_gas_well_test_date)
                .input('total_gas', total_gas)
                .input('gaslift_gas', gaslift_gas_wt)
                .query(gas_well_tests_insert_query);
              logger.log(`|'gas_well_tests'| Populated!`, success);
              gas_well_tests_insertion_count++;
            } else {
              logger.log(`|'gas_well_tests'| Already populated!`);
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
              ((new Date(report_date) - new Date(last_well_test_date)) /
                86400000 >
                15 ||
                (new Date(report_date) - new Date(last_lab_date)) / 86400000 >
                  15)
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
    }
    ////
  }
  await processFiles(inputFolder);
} catch (err) {
  logger.log(err, error, false, true);
  console.log('Database error:', err);
} finally {
  if (pool) {
    await pool.close();
  }
  logger.log(`${'='.repeat(100)}`, 'INFO', true);
  logger.log('SCRIPT EXECUTION FINISHED!', 'INFO', true);
  logger.log(`${'.'.repeat(100)}`, 'INFO', true);
  logger.log(`S U M M A R Y`, 'INFO', true);
  logger.log(
    `${success_count.toString().padStart(6)}\t\tsuccess`,
    'INFO',
    true
  );
  logger.log(`${error_count.toString().padStart(6)}\t\terror`, 'INFO', true);
  logger.log(
    `${warning_count.toString().padStart(6)}\t\twarning`,
    'INFO',
    true
  );
  logger.log(`${info_count.toString().padStart(6)}\t\tinfo`, 'INFO', true);
  logger.log(
    `\n${flowmeter_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'flowmeters'|`,
    'INFO',
    true
  );
  logger.log(
    `${well_stock_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'well_stock'|`,
    'INFO',
    true
  );
  logger.log(
    `${completion_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'completions'|`,
    'INFO',
    true
  );
  logger.log(
    `${well_tests_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'well_tests'|`,
    'INFO',
    true
  );
  logger.log(
    `${gas_well_tests_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'gas_well_tests'|`,
    'INFO',
    true
  );
  logger.log(
    `${daily_well_parameters_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'daily_well_parameters'|`,
    'INFO',
    true
  );
  logger.log(
    `${well_downtime_reasons_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'well_downtime_reasons'|`,
    'INFO',
    true
  );
  logger.log(
    `${laboratory_results_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'laboratory_results'|`,
    'INFO',
    true
  );
  logger.log(
    `${daily_general_comments_insertion_count
      .toString()
      .padStart(6)}\t\trow(s) inserted into |'daily_general_comments'|`,
    'INFO',
    true
  );
  logger.log(`${'.'.repeat(100)}`, 'INFO', true);
  logger.log(`${'*'.repeat(100)}`, 'INFO', true);
}

function getFormattedFilename(folder) {
  const now = new Date();
  const day = String(now.getDate()).padStart(2, '0');
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const year = now.getFullYear();

  return `./${folder}/${day}.${month}.${year}-dpr.log`;
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
