pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        CI = 'true'
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
                        echo 'Security audit reported issues or could not complete. Local demonstration only.'
                    }
                }
            }
        }

        stage('Unit Testing') {
            steps {
                bat 'npm run test -- --run'
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