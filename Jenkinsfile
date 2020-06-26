pipeline {
  agent any

  stages {
    stage('Build Image') {
      steps {
        echo "************ Building an application image ************"
        script {
          openshift.withCluster() {
            openshift.withProject(env.DEV_PROJECT) {
              openshift.selector("bc", "env.APP_NAME").startBuild("--wait=true")
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
              openshift.selector("dc", "env.APP_NAME").rollout().latest();
            }
          }
        }
      }
    }

}
