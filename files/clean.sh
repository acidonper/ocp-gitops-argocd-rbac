##
# Script to prepare Openshift Laboratory
##

##
# Users 
##
USERS="user01
user02
user03
user04
apimanager01
"

##
# Delete groups
##
oc delete group argo-admins
oc delete group argo-readers
oc delete group argo-operators
oc delete group argo-dev-operators
oc delete group argo-integration

##
# Delete users
##
for i in $USERS
do
  oc delete user $i
done

## 
# Create Argo CD projects and applications
##
oc delete -f files/applications/dev-app01.yaml
oc delete -f files/applications/pro-app02.yaml
oc delete -f files/applications/integration-app03.yaml
sleep 10
oc delete -f files/applications/dev-project.yaml
oc delete -f files/applications/pro-project.yaml
oc delete -f files/applications/integration-project-jwt.yaml
sleep 10

## 
# Delete projects
##
oc delete project dev
oc delete project pro
oc delete project integration
oc delete project test

## 
# Refresh ArgoCD Instance
##
oc patch argocd openshift-gitops --patch-file=files/argocd-patch-revert.yaml -n openshift-gitops --type=merge