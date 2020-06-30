#!/bin/bash

echo "###############################################################################"
echo "#  MAKE SURE YOU ARE LOGGED IN:                                               #"
echo "#  $ oc login http://<api-url>                                                #"
echo "###############################################################################"

function usage() {
 echo
    echo "Usage:"
    echo " $0 [command] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " $0 deploy --project-suffix mydemo --appname=appname --repo-url repourl --repo-reference=master --quary-username uname --quay-password quaypasswd --app-name=appname "
    echo
    echo "COMMANDS:"
    echo "   deploy                   Set up the demo projects and deploy demo apps"
    echo "   delete                   Clean up and remove demo projects and objects"
    echo
    echo "OPTIONS:"

    echo "   --quay-username            required    quay.io username to push the images to a quay.io account."
    echo "   --quay-password            required    quay.io password to push the images to a quay.io account."
    echo "   --quay-repo                required    quay.io password to push the images to a quay.io account."
    echo "   --app-name                required     application name for the deployment artifact and openshift resources."
    echo "   --repo-url                 required    The location url of the git repository of the application source code"
    echo "   --repo-reference           required    The branch of the source code repository"
    echo "   --project-suffix [suffix]  Optional    Suffix to be added to demo project names e.g. ci-SUFFIX. If empty, user will be used as suffix"

}

ARG_PROJECT_SUFFIX=
ARG_COMMAND=
ARG_QUAY_USER=
ARG_QUAY_PASS=
ARG_QUAY_REPO=
ARG_REPO_URL=
ARG_REPO_REF=
ARG_APP_NAME=
NUM_ARGS=$#

echo "The number of shell arguments is $NUM_ARGS"

while :; do
    case $1 in
        deploy)
            ARG_COMMAND=deploy
            if [ "$NUM_ARGS" -lt 8 ]; then
              printf 'ERROR: "--the number of arguments cannot be less than 7 for deploy command" \n' >&2
              usage
              exit 255
            fi
            ;;
        delete)
            ARG_COMMAND=delete
            ;;


        --project-suffix)
            if [ -n "$2" ]; then
                ARG_PROJECT_SUFFIX=$2
                shift
            else
                printf 'ERROR: "--project-suffix" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --app-name)
            if [ -n "$2" ]; then
                ARG_APP_NAME=$2
                shift
            else
                printf 'ERROR: "--arg-app-name" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;

        --quay-username)
            if [ -n "$2" ]; then
                ARG_QUAY_USER=$2
                shift
            else
                printf 'ERROR: "--quay-username" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --quay-password)
            if [ -n "$2" ]; then
                ARG_QUAY_PASS=$2
                shift
            else
                printf 'ERROR: "--quay-password" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
            --quay-repo)
                if [ -n "$2" ]; then
                    ARG_QUAY_REPO=$2
                    shift
                else
                    printf 'ERROR: "--quay-repo" requires a non-empty value.\n' >&2
                    usage
                    exit 255
                fi
                ;;
          --repo-url)
            if [ -n "$2" ]; then
                ARG_REPO_URL=$2
                shift
            else
                printf 'ERROR: "--repo-url" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
         --repo-reference)
            if [ -n "$2" ]; then
                ARG_REPO_REF=$2
                shift
            else
                printf 'ERROR: "--repo-reference" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;


        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            shift
            ;;
        *) # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done

DEV_PROJECT=dev-$ARG_PROJECT_SUFFIX
STAGE_PROJECT=stage-$ARG_PROJECT_SUFFIX
CICD_PROJECT=cicd-$ARG_PROJECT_SUFFIX
APP_NAME=$ARG_APP_NAME
REPO_URL=$ARG_REPO_URL
REPO_REF=$ARG_REPO_REF
QUAY_REPO=$ARG_QUAY_REPO
QUAY_USER=$ARG_QUAY_USER
QUAY_PASS=$ARG_QUAY_PASS
template="cisco-cicd-template.yaml"


function setup_projects() {
  echo_header "Setting up projects"
  oc new-project  $DEV_PROJECT   --display-name="$ARG_PROJECT_SUFFIX - Dev"
  oc  new-project $STAGE_PROJECT --display-name="$ARG_PROJECT_SUFFIX - Stage"
  oc  new-project $CICD_PROJECT  --display-name="CI/CD"

  sleep 2

  oc policy add-role-to-group edit system:serviceaccounts:$CICD_PROJECT -n $DEV_PROJECT
  oc policy add-role-to-group edit system:serviceaccounts:$CICD_PROJECT -n $STAGE_PROJECT

  echo "Using template $template"
  echo_header "processing template"
  oc process -f $template -p DEV_PROJECT=$DEV_PROJECT -p STAGE_PROJECT=$STAGE_PROJECT -p CICD_PROJECT=$CICD_PROJECT -p APP_NAME=$APP_NAME  -p QUAY_USERNAME=$QUAY_USER -p QUAY_PASSWORD=$QUAY_PASS -p QUAY_REPO=$QUAY_REPO -p REPO_URL=$REPO_URL -p REPO_REF=$REPO_REF | oc create -f - -n $CICD_PROJECT
}

function setup_applications() {
    echo_header "Setting up Openshift application resources"
    oc new-app jenkins-persistent -n $CICD_PROJECT
    sleep 2

    #cicd
    oc set resources dc/jenkins --limits=cpu=2,memory=4Gi --requests=cpu=1,memory=1Gi
	  oc label dc jenkins app=jenkins --overwrite
    oc create secret generic quay-cicd-secret --from-literal="username=$QUAY_USER" --from-literal="password=$QUAY_PASS" -n $CICD_PROJECT
    oc label secret quay-cicd-secret credential.sync.jenkins.openshift.io=true -n $CICD_PROJECT



	# setup cisco-dev env
    echo_header "Creating application resources in $DEV_PROJECT"
    #oc create secret docker-registry quay-secret --docker-server=quay.io --docker-username="$QUAY_USER" --docker-password="$QUAY_PASS" -n $DEV_PROJECT
    #oc new-build python~$REPO_URL --name=$APP_NAME --push-secret=quay-secret --to-docker --to="quay.io/$QUAY_REPO/$APP_NAME:latest" -n $DEV_PROJECT
    #oc secrets link default quay-secret --for=pull -n $DEV_PROJECT
    #oc new-app --name=$APP_NAME --docker-image=quay.io/$QUAY_REPO/$APP_NAME:latest --allow-missing-images -n $DEV_PROJECT
    oc new-app python:latest~$REPO_URL --name=$APP_NAME
    sleep 2
    oc expose svc $APP_NAME -n $DEV_PROJECT
    oc set triggers dc $APP_NAME --remove-all -n $DEV_PROJECT
    oc patch dc $APP_NAME -p '{"spec": {"template": {"spec": {"containers": [{"name": "'$APP_NAME'", "imagePullPolicy": "Always"}]}}}}' -n $DEV_PROJECT
    oc set probe dc/$APP_NAME --readiness --get-url=http://:8080/hello --initial-delay-seconds=30 --failure-threshold=10 --period-seconds=10 -n $DEV_PROJECT
    oc set probe dc/$APP_NAME --liveness  --get-url=http://:8080 --initial-delay-seconds=180 --failure-threshold=10 --period-seconds=10 -n $DEV_PROJECT
	  oc rollout cancel dc/$APP_NAME -n $DEV_PROJECT

    # cisco-stage
      echo_header "Creating application resources in $STAGE_PROJECT"
    oc create secret docker-registry quay-secret --docker-server=quay.io --docker-username="$QUAY_USER" --docker-password="$QUAY_PASS" -n $STAGE_PROJECT
    oc new-app --name=$APP_NAME --docker-image=quay.io/$QUAY_REPO/$APP_NAME:stage --allow-missing-images -n $STAGE_PROJECT

    oc expose dc $APP_NAME --port=8080 -n $STAGE_PROJECT
    sleep 5
    oc expose svc $APP_NAME -n $STAGE_PROJECT
    oc set triggers dc $APP_NAME --remove-all -n $STAGE_PROJECT
    oc patch dc $APP_NAME -p '{"spec": {"template": {"spec": {"containers": [{"name": "'$APP_NAME'", "imagePullPolicy": "Always"}]}}}}' -n $STAGE_PROJECT

    oc secrets link default quay-secret --for=pull -n $STAGE_PROJECT
    oc set probe dc/$APP_NAME --readiness --get-url=http://:8080/hello --initial-delay-seconds=30 --failure-threshold=10 --period-seconds=10 -n $STAGE_PROJECT
    oc set probe dc/$APP_NAME --liveness  --get-url=http://:8080 --initial-delay-seconds=180 --failure-threshold=10 --period-seconds=10 -n $STAGE_PROJECT
  	oc rollout cancel dc/$APP_NAME -n $STAGE_PROJECT


}

function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}




START=`date +%s`


echo_header "OpenShift CI/CD Demo ($(date))"

case "$ARG_COMMAND" in
    delete)
        echo "Delete demo..."
        oc delete project $DEV_PROJECT $STAGE_PROJECT $CICD_PROJECT
        echo
        echo "Delete completed successfully!"
        ;;


    deploy)
        echo "Deploying demo..."
        setup_projects
        echo
        echo "project setup completed successfully!"
        echo "setting up application artifacts ......."
        setup_applications
        echo "setting up applications completed successfully"
        ;;

    *)
        echo "Invalid command specified: '$ARG_COMMAND'"
        usage
        ;;
  esac


END=`date +%s`
echo "(Completed in $(( ($END - $START)/60 )) min $(( ($END - $START)%60 )) sec)"
