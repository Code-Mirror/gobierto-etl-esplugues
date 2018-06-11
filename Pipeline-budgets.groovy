email = "popu-servers+jenkins@populate.tools "
pipeline {
    agent any
    environment {
        PATH = "/home/ubuntu/.rbenv/shims:$PATH"
        GOBIERTO_ETL_UTILS = "/var/www/gobierto-etl-utils/current/"
        GOBIERTO = "/var/www/gobierto/current/"
        ESPLUGUES_ID = "8077"
        WORKING_DIR="/tmp/esplugues"
    }
    stages {
        stage('Extract > Download data sources') {
            steps {
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/download-s3/run.rb 'esplugues/budgets/AJ-TrimLoc-20181t.xbrl' ${WORKING_DIR}"
            }
        }
        stage('Transform > Transform planned budgets files') {
            steps {
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/xbrl/trimloc/transform-planned/run.rb operations/gobierto_budgets/xbrl/dictionaries/xbrl_trimloc_dictionary.yml ${WORKING_DIR}/AJ-TrimLoc-20181t.xbrl ${ESPLUGUES_ID} 2018 ${WORKING_DIR}/budgets-planned-2018.json"
            }
        }
        stage('Transform > Transform executed budgets files') {
            steps {
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/xbrl/trimloc/transform-execution/run.rb operations/gobierto_budgets/xbrl/dictionaries/xbrl_trimloc_dictionary.yml ${WORKING_DIR}/AJ-TrimLoc-20181t.xbrl ${ESPLUGUES_ID} 2018 ${WORKING_DIR}/budgets-execution-2018.json"
            }
        }
        stage('Load > Import planned file') {
            steps {
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/import-planned-budgets/run.rb ${WORKING_DIR}/budgets-planned-2018.json 2018"
            }
        }
        stage('Load > Import executed files') {
            steps {
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/import-executed-budgets/run.rb ${WORKING_DIR}/budgets-execution-2018.json 2018"
            }
        }
        stage('Load > Calculate totals') {
          steps {
            sh "echo ${ESPLUGUES_ID} > ${WORKING_DIR}/organization.id.txt"
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/update_total_budget/run.rb '2018' ${WORKING_DIR}/organization.id.txt"
          }
        }
        stage('Load > Calculate bubbles') {
          steps {
            sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/bubbles/run.rb ${WORKING_DIR}/organization.id.txt"
          }
        }
        stage('Load > Calculate annual data') {
          steps {
            sh "cd ${GOBIERTO}; bin/rails runner ${GOBIERTO_ETL_UTILS}/operations/gobierto_budgets/annual_data/run.rb '2018' ${WORKING_DIR}/organization.id.txt"
          }
        }
        stage('Load > Publish activity') {
          steps {
            sh "cd ${GOBIERTO}; bin/rails runner ${GOBIERTO_ETL_UTILS}/operations/gobierto/publish-activity/run.rb budgets_updated ${WORKING_DIR}/organization.id.txt"
          }
        }
    }
    post {
        failure {
            echo 'This will run only if failed'
            mail body: "Project: ${env.JOB_NAME} - Build Number: ${env.BUILD_NUMBER} - URL de build: ${env.BUILD_URL}",
                charset: 'UTF-8',
                subject: "ERROR CI: Project name -> ${env.JOB_NAME}",
                to: email
        }
    }
}
