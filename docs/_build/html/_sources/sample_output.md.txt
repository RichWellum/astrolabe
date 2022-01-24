# Sample Output

## Command run

```bash
sudo docker run -it --rm --volume ${SSH_AUTH_SOCK}:/ssh-agent \
--env SSH_AUTH_SOCK=/ssh-agent --volume ${HOME}/.ssh/:/root/.ssh \
--volume ${HOME}/.kube/:/root/.kube rwellum/astrolabe:v1.0
```

## Output

```bash
ubuntu@riwell-k8s-master:~/astrolabe$ ./astrolabe.sh
/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-+
 |                |
 |  Starting...   |
 |                |
 +---------------*/
/*****************************
 *                           *
 *  Krew: installed plugins  *
 *                           *
 *****************************/

PLUGIN             VERSION
datadog            v0.3.0
df-pv              v0.2.7
doctor             v0.3.0
flame              v0.1.8
get-all            v1.3.6
graph              v0.1.1
krew               v0.4.0
pod-dive           v0.1.4
popeye             v0.7.1
resource-capacity  v0.4.0
sick-pods          v0.2.0
starboard          v0.7.1
status             v0.4.1
tail               v0.15.0
view-allocations   v0.9.2
view-utilization   v0.3.3

/****************************************************************
 *                                                              *
 *  view-allocations: Allocated resources across this cluster:  *
 *                                                              *
 ****************************************************************/

 Resource                                          Requested  %Requested    Limit  %Limit  Allocatable   Free
  cpu                                                 950.0m         48%      0.0      0%          2.0    1.1
  └─ riwell-k8s-master                                950.0m         48%      0.0      0%          2.0    1.1
     ├─ coredns-74ff55c5b-8klw9                       100.0m                  0.0
     ├─ coredns-74ff55c5b-bxdhs                       100.0m                  0.0
     ├─ etcd-riwell-k8s-master                        100.0m                  0.0
     ├─ kube-apiserver-riwell-k8s-master              250.0m                  0.0
     ├─ kube-controller-manager-riwell-k8s-master     200.0m                  0.0
     ├─ kube-scheduler-riwell-k8s-master              100.0m                  0.0
     └─ weave-net-rnwz2                               100.0m                  0.0
  ephemeral-storage                                  100.0Mi          0%      0.0      0%        27.9G  27.8G
  └─ riwell-k8s-master                               100.0Mi          0%      0.0      0%        27.9G  27.8G
     └─ etcd-riwell-k8s-master                       100.0Mi                  0.0
  memory                                             440.0Mi          6%  340.0Mi      4%        7.7Gi  7.2Gi
  └─ riwell-k8s-master                               440.0Mi          6%  340.0Mi      4%        7.7Gi  7.2Gi
     ├─ coredns-74ff55c5b-8klw9                       70.0Mi              170.0Mi
     ├─ coredns-74ff55c5b-bxdhs                       70.0Mi              170.0Mi
     ├─ etcd-riwell-k8s-master                       100.0Mi                  0.0
     └─ weave-net-rnwz2                              200.0Mi                  0.0
  pods                                                   0.0          0%      0.0      0%        110.0  110.0
  └─ riwell-k8s-master                                   0.0          0%      0.0      0%        110.0  110.0

/**********************************************************
 *                                                        *
 *  view-utilization: Total Utilization of this Cluster:  *
 *                                                        *
 **********************************************************/

Resource   Requests  %Requests     Limits  %Limits  Allocatable  Schedulable        Free
CPU             950         47          0        0         2002         1052        1052
Memory    461373440          5  356515840        4   8244310016   7782936576  7782936576

/******************************************************************
 *                                                                *
 *  view-utilization: Total Utilization of this Cluster (Human):  *
 *                                                                *
 ******************************************************************/

Resource   Req   %R   Lim  %L  Alloc  Sched  Free
CPU       0.95  47%     0  0%      2    1.1   1.1
Memory    440M   5%  340M  4%   7.7G   7.2G  7.2G

/*******************************************************************************************
 *                                                                                         *
 *  resource-capacity: total CPU and Memory resource requests and limits for all the pods  *
 *                                                                                         *
 *******************************************************************************************/

NODE                NAMESPACE     POD                                         CONTAINER                 CPU REQUESTS   CPU LIMITS   MEMORY REQUESTS   MEMORY LIMITS

riwell-k8s-master   *             *                                           *                         950m (47%)     0m (0%)      440Mi (5%)        340Mi (4%)
riwell-k8s-master   kube-system   weave-net-rnwz2                             *                         100m (5%)      0m (0%)      200Mi (2%)        0Mi (0%)
riwell-k8s-master   kube-system   weave-net-rnwz2                             weave                     50m (2%)       0m (0%)      100Mi (1%)        0Mi (0%)
riwell-k8s-master   kube-system   weave-net-rnwz2                             weave-npc                 50m (2%)       0m (0%)      100Mi (1%)        0Mi (0%)
riwell-k8s-master   kube-system   coredns-74ff55c5b-bxdhs                     *                         100m (5%)      0m (0%)      70Mi (0%)         170Mi (2%)
riwell-k8s-master   kube-system   coredns-74ff55c5b-bxdhs                     coredns                   100m (5%)      0m (0%)      70Mi (0%)         170Mi (2%)
riwell-k8s-master   kube-system   kube-apiserver-riwell-k8s-master            *                         250m (12%)     0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   kube-apiserver-riwell-k8s-master            kube-apiserver            250m (12%)     0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   kube-scheduler-riwell-k8s-master            *                         100m (5%)      0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   kube-scheduler-riwell-k8s-master            kube-scheduler            100m (5%)      0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   kube-proxy-hlf4g                            *                         0m (0%)        0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   kube-proxy-hlf4g                            kube-proxy                0m (0%)        0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   metrics-server-5d5c49f488-hj8cf             *                         0m (0%)        0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   metrics-server-5d5c49f488-hj8cf             metrics-server            0m (0%)        0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   coredns-74ff55c5b-8klw9                     *                         100m (5%)      0m (0%)      70Mi (0%)         170Mi (2%)
riwell-k8s-master   kube-system   coredns-74ff55c5b-8klw9                     coredns                   100m (5%)      0m (0%)      70Mi (0%)         170Mi (2%)
riwell-k8s-master   kube-system   etcd-riwell-k8s-master                      *                         100m (5%)      0m (0%)      100Mi (1%)        0Mi (0%)
riwell-k8s-master   kube-system   etcd-riwell-k8s-master                      etcd                      100m (5%)      0m (0%)      100Mi (1%)        0Mi (0%)
riwell-k8s-master   kube-system   kube-controller-manager-riwell-k8s-master   *                         200m (10%)     0m (0%)      0Mi (0%)          0Mi (0%)
riwell-k8s-master   kube-system   kube-controller-manager-riwell-k8s-master   kube-controller-manager   200m (10%)     0m (0%)      0Mi (0%)          0Mi (0%)

/*********************************************************
 *                                                       *
 *  view-utilization: Overview of namespace utilization  *
 *                                                       *
 *********************************************************/

             CPU        Memory
Namespace     Req  Lim   Req   Lim
kube-system  0.95    0  440M  340M

/*****************************************************
 *                                                   *
 *  view-utilization: Breakdown of node utilization  *
 *                                                   *
 *****************************************************/

CPU   : _
Memory: _
                   CPU                   Memory
Node                Req   %R  Lim    %L   Req   %R   Lim    %L
riwell-k8s-master  0.95  47%    0    0%  440M   5%  340M    4%
```
