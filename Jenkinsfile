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
                  //sh "skopeo copy docker://quay.io/${env.QUAY_REPO}/${env.APP_NAME}:latest docker://quay.io/${env.QUAY_REPO}/${env.APP_NAME}:stage --src-creds \"$QUAY_USER:$QUAY_PWD\" --dest-creds \"$QUAY_USER:$QUAY_PWD\" --src-tls-verify=false --dest-tls-verify=false"

                  //sh "skopeo copy docker://default-route-openshift-image-registry.apps.$(oc whoami --show-server | cut -d. -f2- | cut -d: -f1)/${env.DEV_PROJECT}/${env.APP_NAME}:latest docker://quay.io/${env.QUAY_REPO}/${env.APP_NAME}:stage --src-creds \"$(oc whoami)\":\"$(oc whoami -t)\" --dest-creds \"$QUAY_USER:$QUAY_PWD\" --src-tls-verify=false --dest-tls-verify=false"
                  sh '''registryUser=$(oc whoami)
                        registryPasswd=$(oc whoami -t)
                        skopeo copy docker://default-route-openshift-image-registry.apps.awsocplab01.aztns.com/${env.DEV_PROJECT}/${env.APP_NAME}:latest docker://quay.io/${env.QUAY_REPO}/${env.APP_NAME}:stage --src-creds \\"$registryUser:$registryPasswd\\" --dest-creds \\"$QUAY_USER:$QUAY_PWD\\" --src-tls-verify=false --dest-tls-verify=false'''

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
