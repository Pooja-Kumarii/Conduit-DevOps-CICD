pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        CI = 'true'
        FORCE_COLOR = '0'
        NO_COLOR = '1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Environment Verification') {
            steps {
                bat 'git --version'
                bat 'node --version'
                bat 'npm --version'
            }
        }

        stage('Install Dependencies') {
            steps {
                bat 'npm ci'
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    def result = bat(
                        script: 'npm audit --omit=dev',
                        returnStatus: true
                    )

                    if (result != 0) {
                        echo 'Security audit reported issues. Local demonstration only.'
                    }
                }
            }
        }

        stage('Unit Testing') {
            steps {
                bat 'npm run test -- --run'
            }
        }

        stage('Install Playwright Browser') {
            steps {
                bat 'npx playwright install chromium'
            }
        }

        stage('Playwright Testing') {
            environment {
                NODE_ENV = 'test'
                TEST_DB_USERNAME = 'conduit_user'
                TEST_DB_PASSWORD = credentials('conduit-db-password')
                TEST_DB_NAME = 'conduit_testing'
                TEST_DB_HOSTNAME = '127.0.0.1'
                TEST_DB_DIALECT = 'postgres'
                JWT_KEY = credentials('conduit-jwt-secret')
            }

            steps {
                bat 'npx playwright test'
            }

            post {
                always {
                    archiveArtifacts artifacts: 'playwright-report/**',
                                     allowEmptyArchive: true
                }
            }
        }

        stage('Production Build') {
            steps {
                bat 'npm run build -w frontend'
            }
        }

        stage('Archive Build') {
            steps {
                archiveArtifacts artifacts: 'frontend/dist/**',
                                 fingerprint: true
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Check console output.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}