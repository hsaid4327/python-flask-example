# CI/CD Demo for Python flask application- OpenShift Container Platform 4

This repository contains a simply python flask application, and code to setup an Openshift pipeline for it. 
* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Automated Deploy on OpenShift](#automatic-deploy-on-openshift)



## Introduction
The Openshfit Projects related to the application and different evioronments (cicd, dev, stage) are setup by executing the shell script. The script also creates the resources for applications, Jenkins server and application pipeline. The pipeline execution create the image using s2i process, and then push it to the quay.io registry. On an input from the user, it is then deployed to the stage project
## Prerequisites
The user running the bootstrap script must be logged on to the OCP cluster, and have the permissions to create projects in the OCP cluster

## Automated Deploy on OpenShift
