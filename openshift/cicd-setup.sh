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
    echo " $0 deploy --project-suffix mydemo --repo-url repourl --quary-username uname --quay-password quaypasswd"
    echo
    echo "COMMANDS:"
    echo "   deploy                   Set up the demo projects and deploy demo apps"
    echo "   delete                   Clean up and remove demo projects and objects"
    echo 
    echo "OPTIONS:"
    
    echo "   --quay-username            required    quay.io username to push the images to a quay.io account. Required if --enable-quay is set"
    echo "   --quay-password            required    quay.io password to push the images to a quay.io account. Required if --enable-quay is set"
 
    echo "   --repo-url                 required    The location url of the git repository of the application source code" 
    echo "   --project-suffix [suffix]  Optional    Suffix to be added to demo project names e.g. ci-SUFFIX. If empty, user will be used as suffix"
 
}

ARG_PROJECT_SUFFIX=
ARG_COMMAND=
ARG_QUAY_USER=
ARG_QUAY_PASS=
ARG_REPO_URL=
ARG_REPO_REF=
ARG_APP_NAME=
NUM_ARGS=$#

echo "The number of shell arguments is $NUM_ARGS"

while :; do
    case $1 in
        deploy)
            ARG_COMMAND=deploy
            if [ "$NUM_ARGS" -lt 6 ]; then
              printf 'ERROR: "--the number of arguments cannot be less than 5 for deploy command" \n' >&2
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
        --arg-app-name)
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
                printf 'ERROR: "--rrepo-reference" requires a non-empty value.\n' >&2
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
START=`date +%s`

echo_header "OpenShift CI/CD Demo ($(date))"

case "$ARG_COMMAND" in
    delete)
        echo "Delete demo..."
        oc delete project dev-$ARG_PROJECT_SUFFIX stage-$ARG_PROJECT_SUFFIX cicd-$ARG_PROJECT_SUFFIX
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

function setup_projects() {
  oc new-project dev-$ARG_PROJECT_SUFFIX   --display-name="$ARG_APP_NAME - Dev"
  oc $ARG_OC_OPS new-project stage-$ARG_PROJECT_SUFFIX --display-name="$ARG_APP_NAME - Stage"
  oc $ARG_OC_OPS new-project cicd-$ARG_PROJECT_SUFFIX  --display-name="CI/CD"

  sleep 2

  oc policy add-role-to-group edit system:serviceaccounts:cicd-$ARG_PROJECT_SUFFIX -n dev-$ARG_PROJECT_SUFFIX
  oc policy add-role-to-group edit system:serviceaccounts:cicd-$ARG_PROJECT_SUFFIX -n stage-$ARG_PROJECT_SUFFIX
  
  local template=https://raw.githubusercontent.com/$GITHUB_ACCOUNT/openshift-cd-demo/$GITHUB_REF/cicd-template.yaml
  echo "Using template $template"
  oc $ARG_OC_OPS new-app -f $template -p DEV_PROJECT=dev-$ARG_PROJECT_SUFFIX -p STAGE_PROJECT=stage-$ARG_PROJECT_SUFFIX -p DEPLOY_CHE=$ARG_DEPLOY_CHE -p EPHEMERAL=$ARG_EPHEMERAL -p ENABLE_QUAY=$ARG_ENABLE_QUAY -p QUAY_USERNAME=$ARG_QUAY_USER -p QUAY_PASSWORD=$ARG_QUAY_PASS -n cicd-$ARG_PROJECT_SUFFIX 
}

function setup_applications() {
    oc new-app jenkins-ephemeral -n cicd-$ARG_PROJECT_SUFFIX
    sleep 2
 
    oc set resources dc/jenkins --limits=cpu=2,memory=2Gi --requests=cpu=100m,memory=512Mi 
	oc label dc jenkins app=jenkins --overwrite 
	
	
	# setup cisco-dev env
	oc import-image jboss-eap72 --from=image-registry.openshift-image-registry.svc:5000/openshift/jboss-eap72-openshift --confirm --insecure --confirm -n dev-$ARG_PROJECT_SUFFIX 
	
	if [ "${ENABLE_QUAY}" == "true" ] ; then
	  # cisco-cicd
	  oc create secret generic quay-cicd-secret --from-literal="username=$ARG_QUAY_USER" --from-literal="password=$ARG_QUAY_PASS" -n cicd-$ARG_PROJECT_SUFFIX
	  oc label secret quay-cicd-secret credential.sync.jenkins.openshift.io=true -n cicd-$ARG_PROJECT_SUFFIX
	  
	  # cisco-dev
	  oc create secret docker-registry quay-cicd-secret --docker-server=quay.io --docker-username="$ARG_QUAY_USER" --docker-password="$ARG_QUAY_PASS" --docker-email=cicd@redhat.com -n dev-$ARG_PROJECT_SUFFIX
	  oc new-build --name=tasks --image-stream=jboss-eap72:latest --binary=true --push-secret=quay-cicd-secret --to-docker --to='quay.io/$ARG_QUAY_USER/$QUAY_REPO:latest' -n dev-$ARG_PROJECT_SUFFIX
	  oc new-app --name=tasks --docker-image=quay.io/$ARG_QUAY_USER/$QUAY_REPO:latest --allow-missing-images -n dev-$ARG_PROJECT_SUFFIX
	  oc set triggers dc tasks --remove-all -n dev-$ARG_PROJECT_SUFFIX
	  oc patch dc tasks -p '{"spec": {"template": {"spec": {"containers": [{"name": "tasks", "imagePullPolicy": "Always"}]}}}}' -n dev-$ARG_PROJECT_SUFFIX
	  oc delete is tasks -n dev-$ARG_PROJECT_SUFFIX
	  oc secrets link default quay-cicd-secret --for=pull -n dev-$ARG_PROJECT_SUFFIX
	  
	  # cisco-stage
	  oc create secret docker-registry quay-cicd-secret --docker-server=quay.io --docker-username="$ARG_QUAY_USER" --docker-password="$ARG_QUAY_PASS" --docker-email=cicd@redhat.com -n stage-$ARG_PROJECT_SUFFIX
	  oc new-app --name=tasks --docker-image=quay.io/$ARG_QUAY_USER/$QUAY_REPO:stage --allow-missing-images -n stage-$ARG_PROJECT_SUFFIX
	  oc set triggers dc tasks --remove-all -n stage-$ARG_PROJECT_SUFFIX
	  oc patch dc tasks -p '{"spec": {"template": {"spec": {"containers": [{"name": "tasks", "imagePullPolicy": "Always"}]}}}}' -n stage-$ARG_PROJECT_SUFFIX
	  oc delete is tasks -n stage-$ARG_PROJECT_SUFFIX
	  oc secrets link default quay-cicd-secret --for=pull -n stage-$ARG_PROJECT_SUFFIX
	else
	  # cisco-dev
	  oc new-build --name=tasks --image-stream=jboss-eap72:latest --binary=true -n dev-$ARG_PROJECT_SUFFIX
	  oc new-app tasks:latest --allow-missing-images -n dev-$ARG_PROJECT_SUFFIX
	  oc set triggers dc -l app=tasks --containers=tasks --from-image=tasks:latest --manual -n dev-$ARG_PROJECT_SUFFIX
	  
	  # cisco-stage
	  oc new-app tasks:stage --allow-missing-images -n stage-$ARG_PROJECT_SUFFIX
	  oc set triggers dc -l app=tasks --containers=tasks --from-image=tasks:stage --manual -n stage-$ARG_PROJECT_SUFFIX
	fi
	
	# cisco-dev project
	
	
	oc set probe dc/tasks --readiness --get-url=http://:8080/ws/demo/healthcheck --initial-delay-seconds=30 --failure-threshold=10 --period-seconds=10 -n dev-$ARG_PROJECT_SUFFIX
	oc set probe dc/tasks --liveness  --get-url=http://:8080/ws/demo/healthcheck --initial-delay-seconds=180 --failure-threshold=10 --period-seconds=10 -n dev-$ARG_PROJECT_SUFFIX
	oc rollout cancel dc/tasks -n dev-$ARG_PROJECT_SUFFIX
	# cisco-stage project
	
	
	oc set probe dc/tasks --readiness --get-url=http://:8080/ws/demo/healthcheck --initial-delay-seconds=30 --failure-threshold=10 --period-seconds=10 -n stage-$ARG_PROJECT_SUFFIX
	oc set probe dc/tasks --liveness  --get-url=http://:8080/ws/demo/healthcheck --initial-delay-seconds=180 --failure-threshold=10 --period-seconds=10 -n stage-$ARG_PROJECT_SUFFIX
	oc rollout cancel dc/tasks -n stage-$ARG_PROJECT_SUFFIX 

	
}

function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}










END=`date +%s`
echo "(Completed in $(( ($END - $START)/60 )) min $(( ($END - $START)%60 )) sec)"

