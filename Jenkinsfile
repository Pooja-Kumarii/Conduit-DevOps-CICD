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

        stage('Deploy Application') {
            environment {
                NODE_ENV = 'production'
                PROD_DB_USERNAME = 'conduit_user'
                PROD_DB_PASSWORD = credentials('conduit-db-password')
                PROD_DB_NAME = 'conduit_production'
                PROD_DB_HOSTNAME = '127.0.0.1'
                PROD_DB_DIALECT = 'postgres'
                JWT_KEY = credentials('conduit-jwt-secret')
            }

            steps {
                powershell '.\\scripts\\deploy.ps1'
            }
        }

        stage('Smoke Testing') {
            steps {
                powershell '''
                    $ErrorActionPreference = "Stop"

                    $HomePage = Invoke-WebRequest `
                        -Uri "http://127.0.0.1:3002/" `
                        -UseBasicParsing

                    if ($HomePage.StatusCode -ne 200) {
                        throw "Frontend verification failed"
                    }

                    $Articles = Invoke-RestMethod `
                        -Uri "http://127.0.0.1:3002/api/articles"

                    if ($null -eq $Articles.articles) {
                        throw "Articles API verification failed"
                    }

                    $Tags = Invoke-RestMethod `
                        -Uri "http://127.0.0.1:3002/api/tags"

                    if ($null -eq $Tags.tags) {
                        throw "Tags API verification failed"
                    }

                    Write-Host "Frontend verification: PASSED"
                    Write-Host "Articles API verification: PASSED"
                    Write-Host "Tags API verification: PASSED"
                    Write-Host "All smoke tests passed!"
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully.'
            echo 'Deployed application: http://127.0.0.1:3002'
        }

        failure {
            echo 'Pipeline failed. Check console output.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}