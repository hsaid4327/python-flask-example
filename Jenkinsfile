pipeline {
  agent any

  stages {
    stage('Build Image') {
      steps {
        echo "************ Building an application image ************"
        script {
          openshift.withCluster() {
            openshift.withProject(env.DEV_PROJECT) {
              openshift.selector("bc", env.APP_NAME).startBuild("--wait=true")
            }
          }
        }
      }
    }
    stage('Deploy to env.DEV_PROJECT') {
      steps {
        script {
          openshift.withCluster() {
            openshift.withProject(env.DEV_PROJECT) {
              openshift.selector("dc", env.APP_NAME).rollout().latest();
            }
          }
        }
      }
    }
    stage('Promote to STAGE?') {
        agent {
          label 'skopeo'
        }
        steps {
          timeout(time:15, unit:'MINUTES') {
              input message: "Promote to STAGE?", ok: "Promote"
            }

          script {
            openshift.withCluster() {

                withCredentials([usernamePassword(credentialsId: "${openshift.project()}-quay-cicd-secret", usernameVariable: "QUAY_USER", passwordVariable: "QUAY_PWD")]) {
                  sh "skopeo copy docker://quay.io/${QUAY_USERNAME}/${QUAY_REPOSITORY}:latest docker://quay.io/${QUAY_USERNAME}/${QUAY_REPOSITORY}:stage --src-creds \"$QUAY_USER:$QUAY_PWD\" --dest-creds \"$QUAY_USER:$QUAY_PWD\" --src-tls-verify=false --dest-tls-verify=false"
                }

            }
          }
        }
      }
    stage('Deploy STAGE') {
        steps {
          script {
            openshift.withCluster() {
              openshift.withProject(env.STAGE_PROJECT) {
                openshift.selector("dc", env.APP_NAME).rollout().latest();
              }
            }
          }
        }
      }

 }
}
