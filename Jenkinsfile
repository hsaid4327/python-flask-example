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

                   sh "skopeo copy --src-tls-verify=false --dest-tls-verify=false --src-creds hsaid:\$(oc whoami -t) --dest-creds ${QUAY_USERNAME}:${QUAY_PASSWORD} docker://image-registry.openshift-image-registry.svc.cluster.local:5000/${DEV_PROJECT}/${APP_NAME}:latest docker://quay.io/${QUAY_REPO}/${APP_NAME}:stage"


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
