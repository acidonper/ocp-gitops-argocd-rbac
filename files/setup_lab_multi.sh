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
ADMINS="user01"
READERS="user02"
OPERATORS="user03"
OPERATORS_DEV="user04"
INTEGRATORS="apimanager01"

##
# Adding user to htpasswd
##
htpasswd -c -b users.htpasswd admin password
for i in $USERS
do
  htpasswd -b users.htpasswd $i $i
  oc create user $i
done

for i in $ADMINS
do
  oc adm groups new argo-admins
  oc adm groups add-users argo-admins $i
done

for i in $READERS
do
  oc adm groups new argo-readers
  oc adm groups add-users argo-readers $i
done

for i in $OPERATORS
do
  oc adm groups new argo-operators
  oc adm groups add-users argo-operators $i
done

for i in $OPERATORS_DEV
do
  oc adm groups new argo-dev-operators
  oc adm groups add-users argo-dev-operators $i
done

for i in $INTEGRATORS
do
  oc adm groups new argo-integration
  oc adm groups add-users argo-integration $i
done

##
# Creating htpasswd file in Openshift
##
oc delete secret lab-users -n openshift-config
oc create secret generic lab-users --from-file=htpasswd=users.htpasswd -n openshift-config

##
# Configuring OAuth to authenticate users via htpasswd
##
cat <<EOF > oauth.yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - htpasswd:
      fileData:
        name: lab-users
    mappingMethod: claim
    name: lab-users
    type: HTPasswd
EOF

cat oauth.yaml | oc apply -f -

##
# Disable self namespaces provisioner 
##
oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'

## 
# Install GitOps Operator
##
oc apply -f ./files/redhat_gitops.yaml

## 
# Create projects
##
oc new-project dev
oc label namespace dev argocd.argoproj.io/managed-by=openshift-gitops
oc new-project pro
oc label namespace pro argocd.argoproj.io/managed-by=openshift-gitops

## 
# Create projects and applications
##
oc apply -f files/applications/dev-app01.yaml
oc apply -f files/applications/pro-app02.yaml
oc apply -f files/applications/dev-project.yaml
oc apply -f files/applications/pro-project.yaml