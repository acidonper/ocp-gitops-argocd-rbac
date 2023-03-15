# Red Hat Openshift GitOps RBAC 

GitOps uses Git repositories as a single source of truth to deliver infrastructure as code. Submitted code checks the CI process, while the CD process checks and applies requirements for things like security, infrastructure as code, or any other boundaries set for the application framework. All changes to code are tracked, making updates easy while also providing version control should a rollback be needed.

This solution is based on Argo CD and the following sections try to collect some information about RBAC in this solution.

## Prerequisites

- Red Hat Openshift +4.12
- OC Client +4.12
- argocd CLI +v2.6.5

## Setting Up

First of all, it is required create the respective users, groups and resources following the next procedure:

```$bash
$ sh files/setup_lab_multi.sh
```

After the command is finished, the Openshift cluster has the following configuration:

- Red Hat GitOps operator
- Htpasswd Authentication Provider
- Users: user01, user02, user03, user04 and apimanager01
- Groups: argo-admins (user01), argo-readers (user02), argo-operators (user03) & argo-dev-operators (user04)
- Some applications

## RBAC in Argo CD

ArgoCD Role-Based Access Control (RBAC) is summarized in two major groups:

- ArgoCD Roles: permissions assigned to the ArgoCD users for creating and operating objects in ArgoCD (*Managed internally by ArgoCD)
- Kubernetes API Roles: permissions assigned to the application controller’s ServiceAccount for creating/modifying/deleting objects in Red Hat OpenShift Container Platform (*Managed by Kubernetes)

The following sections collect the information around Argo CD Roles and Argo CD permission in the Openshift clusters. It is important to understand the functionality matrix and permission that the following sections try to implement:

- argo-admins group members have full permissions in Argo CD to admin 
- argo-readers group members have read-only permissions in Argo CD to access all information
- argo-operators group members have permission to manage applications (get and sync) only in Argo CD
- argo-dev-operators group members have permission to manage applications (get and sync) only in Argo CD *dev* project 
- apimanager01 user has no permissions to see anything in Argo CD but has permissions to create objects in the Openshift Clusters

### Argo CD Roles & Policies

The RBAC feature enables restriction of access to Argo CD resources. Argo CD does not have its own user management system and has only one built-in user admin. The admin user is a superuser and it has unrestricted access to the system. RBAC requires SSO configuration or one or more local users setup. Once SSO or local users are configured, additional RBAC roles can be defined, and SSO groups or local users can then be mapped to roles.

Argo CD has two pre-defined roles but RBAC configuration allows defining roles and groups (see below).

- role:readonly - read-only access to all resources
- role:admin - unrestricted access to all resources

Additionally to the defined roles, it is possible to create some specific roles to allow argo-operators and argo-dev-operators group members manage applications in Argo CD. With this in mind and the groups/users created previously during the setting up process, the following procedure creates an Argo CD instance with specific permission for the groups/users created:

- Deploy the respective Argo CD RBAC configuration with specific permissions

```$bash
$ oc patch argocd openshift-gitops --patch-file=files/argocd-patch.yaml -n openshift-gitops --type=merge
```

- Access to Argo CD console and check the specific permissions for the different users

```$bash
$ oc get route openshift-gitops-server -n openshift-gitops
```

* user01 -> Admin permissions in ALL projects and applications
* user02 -> Read-only permissions in ALL projects and applications
* user03 -> View and Sync permission in ALL projects and applications
* user04 -> View and Sync permission in DEV project and its applications

### Openshift Cluster Permissions

Argo CD application controller is the process or microservice that talks directly to the Kubernetes API to apply the resources. Depending on the cluster where should be required to apply the objects, it is necessary to provide some permissions to the Argo CD application controller service in different ways.

**Local Cluster**

Most of the time, Argo CD applications are configured to deploy objects in the local cluster. In this case, ArgoCD application controller service account has to be allowed to create objects in the different namespaces where the applications will have to be deployed in terms of local permissions.

Red Hat Openshift GitOps operator provides an automated process to grant permissions to the ArgoCD application controller service account labeling a namespace with a specific label. This process adds a specific role and rolebinding in the target namespaces granting the respective permission to the ArgoCD application controller service account.

Please execute the next procedure in order to review this functionality:

```$bash
$ oc new-project test

$ oc label namespace test argocd.argoproj.io/managed-by=openshift-gitops

$ oc get role
NAME                                             CREATED AT
openshift-gitops-argocd-application-controller   2023-03-15T08:07:28Z
...

$ oc get rolebinding
NAME                                             ROLE                                                  AGE
admin                                            ClusterRole/admin                                     16h
openshift-gitops-argocd-application-controller   Role/openshift-gitops-argocd-application-controller   100m
...
```

**Remote Cluster**

Regarding managing remote clusters, it is necessary to provide a cluster user credentials and assign specific permissions to this user in the remote cluster. The following example tries to illustrate an example where it is required to execute an automated sync process to Argo CD applications using a remote cluster.

> **IMPORTANT**
> 
> It is required to change the Openshift API hostname in every step

- Create a namespace named integration

```$bash
$ oc new-project integration
```

- Create a *cluster* configuration secret in order to be able to manage the remote cluster with the admin user

```$bash
$ API_DOMAIN=acidonpe34.sandbox766.opentlc.com API_TOKEN=$(oc whoami -t) envsubst < files/argocd-cluster-secret-token.yaml | oc apply -f -
```

> **NOTE**
> 
> Take a look at this file in order to understand the configuration defined (user, pass, cluster url, etc)

- Create a specific project and application in Argo CD using this credentials

```$bash
$ oc apply -f files/applications/integration-project.yaml

$ API_DOMAIN=acidonpe34.sandbox766.opentlc.com envsubst < files/applications/integration-app03.yaml | oc apply -f -
```

> **NOTE**
> 
> Some errors appear because of project configuration. Take a look at the *files/applications/integration-project.yaml* file in order to understand the situation

- Reconfigure integration project

```$bash
oc apply -f files/applications/integration-project-ok.yaml
```

### External Integration ArgoCD

It is possible to integrate Argo CD application management using specific JWT token generated by the *argocd* CLI. In the following procedure, a JWT will be created and used to define a specific role to modify and sync applications.

- Create a specific JWT with the argocd CLI

```$bash
$ ARGO_PASS=$(oc get secret openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' -n openshift-gitops | base64 -d)

$ argocd login openshift-gitops-server-openshift-gitops.apps.acidonpe34.sandbox766.opentlc.com --username admin --password ${ARGO_PASS} --insecure

$ argocd proj role create-token integration argo-integration
...
  Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmdvY2QiLCJzdWIiOiJwcm9qOmludGVncmF0aW9uOmFyZ28taW50ZWdyYXRpb24iLCJuYmYiOjE2Nzg4ODM4NTYsImlhdCI6MTY3ODg4Mzg1NiwianRpIjoiNTRjMTZmODYtYzA4ZS00NDg1LTk3YWYtZDQ0NjI4OWQwMWM3In0.oMC_HrzSSTCEO4bMEAusfPu9kvNkSa_HY_S1E_gMJAg
```

> **NOTE**
>
> JWT tokens aren't stored in Argo CD, they can only be retrieved when they are created

- Obtain the respective *iat* from the JWT

```$bash
$ JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmdvY2QiLCJzdWIiOiJwcm9qOmludGVncmF0aW9uOmFyZ28taW50ZWdyYXRpb24iLCJuYmYiOjE2Nzg4ODM4NTYsImlhdCI6MTY3ODg4Mzg1NiwianRpIjoiNTRjMTZmODYtYzA4ZS00NDg1LTk3YWYtZDQ0NjI4OWQwMWM3In0.oMC_HrzSSTCEO4bMEAusfPu9kvNkSa_HY_S1E_gMJAg"

$ echo $JWT | sed 's/\./\n/g' <<< $(cut -d. -f1,2 <<< $1) | base64 --decode | jq
...
  "iat": 1678883856,
...
```

- Test the current permissions of this JWT 

```$bash
$ argocd app sync app03-integration --auth-token $JWT       

FATA[0001] rpc error: code = PermissionDenied desc = permission denied: applications, get, integration/app03-integration, sub: proj:integration:argo-integration, iat: 2023-03-15T12:37:36Z
```

- Modify the project file to add permissions to this JWT and apply the changes

```$bash
$ vi files/applications/integration-project-ok.yaml
...
    jwtTokens:
      - iat: 1678883856

$ apply -f files/applications/integration-project-ok.yaml
```

- Test the current permissions of this JWT 

```$bash
$ argocd app sync app03-integration --auth-token $JWT
...
Operation:          Sync
Sync Revision:      4842f40394df6b2a4a5f9af3caf28aff6c3efeae
Phase:              Succeeded
Start:              2023-03-15 13:46:43 +0100 CET
Finished:           2023-03-15 13:46:44 +0100 CET
Duration:           1s
Message:            successfully synced (all tasks run)
...
```

### Sync Windows

Sync windows are configurable windows of time where syncs will either be blocked or allowed. In the following example, a windows block will be defined in the *integration* application in order to test this functionality.

- Modify the project file to include the sync windows restriction

```$bash
$ oc apply -f files/applications/integration-project-window.yaml
```

- Login with argocd CLI and try to sync the integration application

```$bash
$ ARGO_PASS=$(oc get secret openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' -n openshift-gitops | base64 -d)

$ argocd login openshift-gitops-server-openshift-gitops.apps.acidonpe34.sandbox766.opentlc.com --username admin --password ${ARGO_PASS} --insecure

$ argocd app sync app03-integration
FATA[0001] rpc error: code = PermissionDenied desc = cannot sync: blocked by sync window 
```

> **NOTE**
> 
> In the Argo CD web interface appears a specific section called *Sync Windows* that reflects the current state of this restriction

## Interesting links

* https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
* https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/
* https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/

## Author

Asier Cidon @RedHat