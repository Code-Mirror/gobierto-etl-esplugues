#!/bin/bash

set -e

YEAR=2020
WORKING_DIR=/tmp/esplugues
GOBIERTO_ETL_UTILS=$DEV_DIR/gobierto-etl-utils

# Extract > Download data sources
XBRL_FILE="08077AA000-Penloc-2020.xbrl"
cd $GOBIERTO_ETL_UTILS; ruby operations/download-s3/run.rb "esplugues/budgets/$XBRL_FILE" $WORKING_DIR/
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/xbrl/penloc/transform-planned/run.rb operations/gobierto_budgets/xbrl/dictionaries/xbrl_penloc_dictionary.yml $WORKING_DIR/$XBRL_FILE 8077 $YEAR $WORKING_DIR/budgets-planned-$YEAR.json
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/budgets-planned-$YEAR.json $YEAR

# Extract > Download data sources
XBRL_FILE="AJ-TrimLoc-2020_1t.xbrl"
cd $GOBIERTO_ETL_UTILS; ruby operations/download-s3/run.rb "esplugues/budgets/$XBRL_FILE" $WORKING_DIR/
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/xbrl/trimloc/transform-planned/run.rb operations/gobierto_budgets/xbrl/dictionaries/xbrl_trimloc_dictionary.yml $WORKING_DIR/$XBRL_FILE 8077 $YEAR $WORKING_DIR/budgets-planned-$YEAR.json
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/budgets-planned-$YEAR.json $YEAR

# Load > Calculate totals
echo "8077" > $WORKING_DIR/organization.id.txt
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/update_total_budget/run.rb $YEAR $WORKING_DIR/organization.id.txt

# Load > Calculate bubbles
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Calculate annual data
cd $DEV_DIR/gobierto/; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto_budgets/annual_data/run.rb $YEAR $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $DEV_DIR/gobierto/; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/publish-activity/run.rb budgets_updated $WORKING_DIR/organization.id.txt

# Clear cache
cd $DEV_DIR/gobierto; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/clear-cache/run.rb
