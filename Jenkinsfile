pipeline {
  options {
    preserveStashes()
  }
  agent none
  stages {
    stage('Init') {
      input {
        message 'Set Parameters:'
        parameters {
          choice choices: ['Any', 'Linux', 'Windows', 'Docker'], description: 'Build Agent', name: 'BUILD_AGENT'
          choice choices: ['Debug', 'Release', 'MinSizeRel', 'RelWithDebInfo'], description: 'Build Type', name: 'BUILD_TYPE'
        }
      }
      steps {
        script {
          env.BUILD_AGENT = BUILD_AGENT == 'Any' ? '' : BUILD_AGENT
          env.BUILD_TYPE = BUILD_TYPE
          parallel (
            "${BUILD_AGENT} - ${BUILD_TYPE}": {
              stage('Set Parameters') {
                echo "Build Agent: ${BUILD_AGENT}"
                echo "Build Type: ${BUILD_TYPE}"
              }
            }
          )
        }
      }
    }
    stage('Check') {
      options {
        timeout(time: 5, unit: 'SECONDS')
      }
      agent { label env.BUILD_AGENT }
      steps {
          echo "Build Agent: ${env.BUILD_AGENT}"
          echo "Build Type: ${env.BUILD_TYPE}"
      }
    }
    stage('Build') {
      parallel {
        stage('Unix') {
          agent { label env.BUILD_AGENT }
          when { expression { isUnix() } }
          steps {
            sh '''make venv_create
`make --no-print-directory venv_activate`
python -m pip install --upgrade pip
make cmake_project
make build'''
            stash includes: "${env.BUILD_TYPE}/**", name: 'build'
          }
        }
        stage('Windows') {
          agent { label env.BUILD_AGENT }
          when { expression { !isUnix() } }
          steps {
            bat '''make venv_create
make venv_activate
python -m pip install --upgrade pip
make cmake_project
make build'''
            stash includes: "${env.BUILD_TYPE}/**", name: 'build'
          }
        }
      }
    }
    stage('Test') {
      environment {
        GTEST_OUTPUT = 'xml:../gtest/'
      }
      parallel {
        stage('Unix') {
          agent { label env.BUILD_AGENT }
          when { expression { isUnix() } }
          steps {
            unstash 'build'
            sh "cd ${env.BUILD_TYPE} && ctest -C ${env.BUILD_TYPE} -T Test --no-compress-output"
            stash includes: "${env.BUILD_TYPE}/**", name: 'test'
          }
        }
        stage('Windows') {
          agent { label env.BUILD_AGENT }
          when { expression { !isUnix() } }
          steps {
            unstash 'build'
            bat "cd ${env.BUILD_TYPE} && ctest -C ${env.BUILD_TYPE} -T Test --no-compress-output"
            stash includes: "${env.BUILD_TYPE}/**", name: 'test'
          }
        }
      }
      post {
        always {
          node(env.BUILD_AGENT) {
            unstash 'test'
            archiveArtifacts artifacts: "${env.BUILD_TYPE}/Testing/**/*.xml, ${env.BUILD_TYPE}/gtest/**/*.xml", fingerprint: true
            xunit (
              thresholds: [ skipped(failureThreshold: '0'), failed(failureThreshold: '0') ],
              tools: [
                CTest(pattern: "${env.BUILD_TYPE}/Testing/**/*.xml", deleteOutputFiles: true, failIfNotNew: false, skipNoTestFiles: true, stopProcessingIfError: true),
                GoogleTest(pattern: "${env.BUILD_TYPE}/gtest/**/*.xml", deleteOutputFiles: true, failIfNotNew: false, skipNoTestFiles: true, stopProcessingIfError: true)
              ]
            )
          }
        }
      }
    }
    stage('Pack') {
      parallel {
        stage('Unix') {
          agent { label env.BUILD_AGENT }
          when { expression { isUnix() } }
          steps {
            unstash 'build'
            sh 'make package'
            stash includes: "${env.BUILD_TYPE}/**", name: 'pack'
          }
          post {
            success {
              script {
                env.PACKAGE_FILE_NAME = sh(script: 'make --no-print-directory package_file_name', returnStdout: true).trim()
              }
            }
          }
        }
        stage('Windows') {
          agent { label env.BUILD_AGENT }
          when { expression { !isUnix() } }
          steps {
            unstash 'build'
            bat 'make package'
            stash includes: "${env.BUILD_TYPE}/**", name: 'pack'
          }
          post {
            success {
              script {
                env.PACKAGE_FILE_NAME = bat(script: 'make package_file_name', returnStdout: true).trim()
              }
            }
          }
        }
      }
      post {
        success {
          node(env.BUILD_AGENT) {
            unstash 'pack'
            archiveArtifacts artifacts: "${env.BUILD_TYPE}/${env.PACKAGE_FILE_NAME}*", fingerprint: true
          }
        }
      }
    }
    stage('Deploy') {
      agent { label env.BUILD_AGENT }
      steps {
        input 'Deploy?'
      }
    }
  }
}
