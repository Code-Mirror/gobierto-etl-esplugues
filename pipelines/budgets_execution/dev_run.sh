#!/bin/bash

XBRL_FILE="AJ-TrimLoc-20181t.xbrl"
WORKING_DIR=/tmp/esplugues
GOBIERTO_ETL_UTILS=$DEV_DIR/gobierto-etl-utils

# Extract > Download data sources
cd $GOBIERTO_ETL_UTILS; ruby operations/download-s3/run.rb "esplugues/budgets/$XBRL_FILE" $WORKING_DIR/

cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/xbrl/trimloc/transform-execution/run.rb operations/gobierto_budgets/xbrl/dictionaries/xbrl_trimloc_dictionary.yml $WORKING_DIR/$XBRL_FILE 8077 2018 $WORKING_DIR/budgets-execution-2018.json

cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-executed-budgets/run.rb $WORKING_DIR/budgets-execution-2018.json 2018

# Load > Calculate totals
echo "8077" > $WORKING_DIR/organization.id.txt
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/update_total_budget/run.rb "2018" $WORKING_DIR/organization.id.txt

# Load > Calculate bubbles
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Calculate annual data
cd $DEV_DIR/gobierto/; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto_budgets/annual_data/run.rb "2018" $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $DEV_DIR/gobierto/; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/publish-activity/run.rb budgets_updated $WORKING_DIR/organization.id.txt