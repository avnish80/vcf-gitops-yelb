# vcf-gitops-yelb

Yelb (VMware's 3-tier demo app) deployed by **one Argo CD instance** across **three VCF runtimes**,
using the VCF Automation GitOps service (Argo CD Service 1.2.0) on VCF 9.1.1.

| Tier | Runtime | Path | Argo CD target |
|---|---|---|---|
| Postgres DB | VM Service VM (Ubuntu 24.04 + cloud-init) | `infra/db-vm` | attached vSphere Namespace `org2-ns1-mrrtd` |
| Appserver + Redis | vSphere Pods | `infra/appserver` | attached vSphere Namespace |
| VKS cluster `yelb-vks` | Cluster API on Supervisor | `infra/vks-cluster` | attached vSphere Namespace |
| Cluster registration | `ManagedEntity` (Argo CD Service API) | `infra/registration` | attached vSphere Namespace |
| UI | Pods inside `yelb-vks` | `workloads/yelb-ui` | `yelb-vks`, found by the ApplicationSet via label `app=yelb` |

```
browser ──► yelb-ui (VKS, LB) ──► yelb-appserver (vSphere Pods, LB :4567) ──► yelb-db (VM, :5432)
                                                     └──► redis-server (vSphere Pod, :6379)
```

## Environment assumptions
- Argo CD instance `org2-argo` in namespace `org2-ns1-mrrtd`, with that namespace attached (Argo CD destination name `org2-ns1-mrrtd`).
- VM class `best-effort-small` / `best-effort-medium`, image `vmi-5ab37e711e9121b34` (noble cloudimg), storage class `cluster-wld01-01a-optimal-datastore-default-policy-autoraid`.
- ClusterClass `builtin-generic-v3.7.0` in `vmware-system-vks-public`, VKr `v1.36.2+vmware.2`.
- Docker Hub reachable from vSphere Pods and VKS nodes.

## Deploy
```bash
# 0. Pre-flight (Supervisor context)
kubectl -n org2-ns1-mrrtd get appprojects                 # "default" must exist
kubectl explain managedentity.spec.targetRef.kind         # confirm Cluster is an accepted kind

# 1. Bootstrap: create the child Applications + ApplicationSet in the Argo CD namespace
kubectl apply -f apps/
```
Order is handled by retries: the appserver retries until the DB service exists, registration retries
until the cluster exists, and the ApplicationSet creates `yelb-ui-yelb-vks` once the cluster is registered.

### The one manual GitOps step
```bash
kubectl -n org2-ns1-mrrtd get svc yelb-appserver         # note EXTERNAL-IP
# edit workloads/yelb-ui/appserver-bridge.yaml: replace 192.0.2.10 with that IP
git commit -am "yelb-ui: point bridge at appserver LB" && git push
```

## Verify
```bash
kubectl -n org2-ns1-mrrtd get vm,vmservice,deploy,svc,cluster,managedentities -l app=yelb
kubectl -n org2-ns1-mrrtd get applications,applicationsets
# in yelb-vks: kubectl -n yelb get pods,svc  -> open http://<yelb-ui EXTERNAL-IP>
```

## Teardown
`kubectl delete -f apps/` removes the Applications. Pruning deletes the VM, pods and registration;
the Cluster carries `Prune=false`, so delete it explicitly when you are done:
`kubectl -n org2-ns1-mrrtd delete cluster yelb-vks`.

> Lab only: the DB uses Yelb's built-in `postgres_password` and accepts md5 logins from any address.
