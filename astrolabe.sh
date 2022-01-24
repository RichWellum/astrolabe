#!/bin/bash
# Retrieve and display data, CPU, MEM and Cost about a Cluster and Nodes in a cluster
#
# Tools installed and run with kubectl krew:
#   view-utilization
#   resource-capacity
#   view-allocations
#   view-allocations
#   resource-snapshot
#   df-pv
#
# In addition this script runs a new daemonset that pulls disk data from all
# pods in the cluster
#

# Add -xv to first line and uncomment the below for line debug
# PS4='${LINENO}: '
export PATH="${PATH}:${HOME}/.krew/bin"
if [[ "$PRETTY" == "true" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    # No colors if not pretty
    RED='\033[0m'
    GREEN='\033[0m'
    CYAN='\033[0m'
    NC='\033[0m'
fi

# Stop Golang debugs
unset DEBUG

CLUSTER_NAME=$(kubectl config current-context)
#       Node  Disk  Disk  Mem  Mem  Inst  Linux CPU  Thr  CPU% CR    Stor  Taints
HEADER="%-34s %-10s %-10s %-9s %-9s %-17s %-19s %-5s %-5s %-5s %-11s %-10s %-10s\n"

#
# 'false', 'v', 'vv' - all other strings sets to false
#
VERBOSE=$1
if [[ "$VERBOSE" != "false" ]] && [[ "$VERBOSE" != "v" ]] && [[ "$VERBOSE" != "vv" ]]; then
    VERBOSE="false"
fi

#
# If PRETTY is true - use boxes and spinners etc
#
PRETTY=$2

#
# If LOW_DATA is true - retrieve just the minimum data
#
LOW_DATA=$3
if [[ "$LOW_DATA" == "true" ]]; then
    PRETTY="false"
fi

#
# Start user functions
#

function get_pv_info() {
    #
    # Persistent volume data
    #
    if [[ "$PRETTY" == "false" ]]; then
        return
    fi
    echo "Persistent Volume Utilization" | boxes -d stone >>/home/astrolabe.pv
    kubectl df-pv -d >>/home/astrolabe.pv
    echo >>/home/astrolabe.pv
    cat /home/astrolabe.pv >>/home/astrolabe.pernode_table_sorted
}

function get_top_pods() {
    if [[ "$LOW_DATA" == "true" ]]; then
        return
    fi
    if [[ "$PRETTY" == "true" ]]; then
        echo "Top Pods information" | boxes -d stone >>/home/astrolabe.top_pods
    else
        echo "Top Pods information" >>/home/astrolabe.top_pods
        echo "--------------------" >>/home/astrolabe.top_pods
    fi
    echo >>/home/astrolabe.top_pods

    # Top pods by CPU
    echo "Top Ten Pods by CPU usage" >>/home/astrolabe.top_pods
    echo -e "-------------------------\n" >>/home/astrolabe.top_pods

    kubectl top pods -A --use-protocol-buffers | head -n 1 >>/home/astrolabe.top_pods
    kubectl top pods -A --use-protocol-buffers | sort --reverse --key 3 --numeric | awk 'NR<=10' >>/home/astrolabe.top_pods
    echo >>/home/astrolabe.top_pods

    # Top pods by MEM
    echo "Top Ten Pods by Mem usage" >>/home/astrolabe.top_pods
    echo -e "-------------------------\n" >>/home/astrolabe.top_pods

    kubectl top pods -A --use-protocol-buffers | head -n 1 >>/home/astrolabe.top_pods
    kubectl top pods -A --use-protocol-buffers | sort --reverse --key 4 --numeric | awk 'NR<=10' >>/home/astrolabe.top_pods
    echo >>/home/astrolabe.top_pods

    cat /home/astrolabe.top_pods >>/home/astrolabe.pernode_table_sorted
}

function enable_kubecost() {
    if [[ "$LOW_DATA" == "true" ]]; then
        return
    fi
    KUBECOST_RUN=$(kubectl get namespaces | grep kubecost)
    if [ -z "$KUBECOST_RUN" ]; then
        if [[ "$PRETTY" == "true" ]]; then
            start_spinner 'Starting kubecost....'
        fi
        kubectl create namespace kubecost &>/dev/null
        helm repo add kubecost https://kubecost.github.io/cost-analyzer/ &>/dev/null
        helm install kubecost kubecost/cost-analyzer --namespace kubecost --set kubecostToken="cmljaHdlbGx1bUBnbWFpbC5jb20=xm343yadf98" &>/dev/null
        sleep 3
        POD=$(kubectl get pods --all-namespaces | grep kubecost-cost-analyzer | awk '{print $2}')
        while [ $(kubectl get pod $POD -n kubecost | grep 3/3 | wc -l | xargs) != "1" ]; do
            sleep 5
            echo "Waiting for kubecost-cost-analyzer to be ready."
        done
        sleep 30 # Seems to take a while when first starting
        if [[ "$PRETTY" == "true" ]]; then
            stop_spinner $?
        fi
    fi
}

function get_kubecost_data() {
    # kubecost commands and outputs
    #
    # There are several supported subcommands: namespace, deployment, controller,
    # label, and tui, which display cost information aggregated by the name of the
    # subcommand (see Examples). Each subcommand has two primary modes, rate and
    # non-rate. Rate (the default) displays the projected monthly cost based on the
    # activity during the window. Non-rate (--historical) displays the total cost
    # for the duration of the window.

    # Historical=total cost for the duration of the window
    # Non-historical = the projected monthly cost during window

    if [[ "$LOW_DATA" == "true" ]]; then
        return
    fi
    if [[ "$PRETTY" == "true" ]]; then
        echo "KubeCost Information" | boxes -d stone >>/home/astrolabe.kubecost
    else
        echo "KubeCost Information" >>/home/astrolabe.kubecost
        echo -e "--------------------\n" >>/home/astrolabe.kubecost
    fi
    echo >>/home/astrolabe.kubecost

    # Actual costs per namespace duration the last 1 month
    echo -e "Top most expensive Namespaces" >>/home/astrolabe.kubecost
    echo -e "-----------------------------\n" >>/home/astrolabe.kubecost

    if [[ "$PRETTY" == "true" ]]; then
        kubectl cost namespace \
            --historical \
            --window month \
            --show-cpu \
            --show-memory \
            >>/home/astrolabe.kubecost
    else
        kubectl cost namespace \
            --historical \
            --window month \
            --show-all-resources \
            >>/home/astrolabe.kubecost
    fi
    echo >>/home/astrolabe.kubecost

    # # Actual monthly rate for each deployment in duration the last 1 month
    echo -e "Top most expensive Deployments" >>/home/astrolabe.kubecost
    echo -e "------------------------------\n" >>/home/astrolabe.kubecost

    if [[ "$PRETTY" == "true" ]]; then
        kubectl cost deployment \
            --historical \
            --window month \
            --show-all-resources | awk 'NR<=20' \
            >>/home/astrolabe.kubecost
    else
        kubectl cost deployment \
            --historical \
            --window month \
            --show-cpu \
            --show-memory | awk 'NR<=20' \
            >>/home/astrolabe.kubecost
    fi
    echo >>/home/astrolabe.kubecost

    # Actual monthly rate for each pod in duration the last 1 month
    echo -e "Top most expensive Pods" >>/home/astrolabe.kubecost
    echo -e "-----------------------\n" >>/home/astrolabe.kubecost

    if [[ "$PRETTY" == "true" ]]; then
        kubectl cost pod \
            --historical \
            --window month \
            --show-all-resources | awk 'NR<=20' \
            >>/home/astrolabe.kubecost
    else
        kubectl cost pod \
            --historical \
            --window month \
            --show-cpu \
            --show-memory | awk 'NR<=20' \
            >>/home/astrolabe.kubecost
    fi
    echo >>/home/astrolabe.kubecost

    # Projected monthly costs per namespace using last 7d window
    echo -e "Top Projected Namespaces using 7 days window of data" >>/home/astrolabe.kubecost
    echo -e "----------------------------------------------------\n" >>/home/astrolabe.kubecost

    if [[ "$PRETTY" == "true" ]]; then
        kubectl cost namespace \
            --show-all-resources \
            --window 7d | awk 'NR<=20' \
            >>/home/astrolabe.kubecost
    else
        kubectl cost namespace \
            --show-cpu \
            --show-memory \
            --window 7d | awk 'NR<=20' \
            >>/home/astrolabe.kubecost
    fi
    echo >>/home/astrolabe.kubecost

    # End of output here
    if [[ "$PRETTY" == "true" ]]; then
        echo "----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----" >>/home/astrolabe.kubecost
    fi
    cat /home/astrolabe.kubecost >>/home/astrolabe.pernode_table_sorted
}

function display_daemonset() {
    return
    echo
    echo -en ${GREEN}
    kubectl get pods -n astrolabe | grep disk-checker
    echo -en ${NC}
    echo
}

function wait_for_daemonset() {
    retries=10
    sleep 1
    desired=$(kubectl get daemonset -n astrolabe -l=app='disk-checker' | grep -v NAME | awk '{print $2}')
    while [[ $retries -ge 0 ]]; do
        ready=$(kubectl get daemonset -n astrolabe -l=app='disk-checker' | grep -v NAME | awk '{print $4}')
        display_daemonset
        if ((ready == desired)); then
            if [[ "$PRETTY" == "true" ]]; then
                echo -e "${CYAN}Desired ($desired) pods == Ready ($ready) pods....${NC}"
            fi
            break
        fi
        ((retries--))
        sleep 5
    done
}

function wait_for_daemonset_to_die() {
    sleep 3
    PODS=$(kubectl get pods -n astrolabe &>/dev/null | grep disk-ckecker | wc -l)
    while [[ $PODS -ne 0 ]]; do
        sleep 3
        PODS=$(kubectl get pods -n astrolabe | grep disk-ckecker | wc -l | sed 's/^[[:space:]]*//g') &>/dev/null
    done
}

function BytesToHuman() {
    # https://unix.stackexchange.com/questions/44040/a-standard-tool-to-convert-a-byte-count-into-human-kib-mib-etc-like-du-ls1/259254#259254

    read StdIn

    b=${StdIn:-0}
    d=''
    s=0
    S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

function get_cni() {
    # Todo - works for Azure only
    system_node=$(kubectl get node | grep "\-cas\-" | awk 'NR==1 {print $1}' | xargs)
    CNI_NAM=$(kubectl node-shell $system_node -- sh -c 'cat /etc/cni/net.d/10-*.conflist | grep name')
    CNI_VER=$(kubectl node-shell $system_node -- sh -c 'cat /etc/cni/net.d/10-*.conflist | grep cniV')
    export CNI_NAM=$(echo $CNI_NAM | awk 'NR==2 {print $1}' | sed 's/,//g' | xargs | sed 's/name://g')
    export CNI_VER=$(echo $CNI_VER | awk 'NR==2 {print $1}' | sed 's/,//g' | xargs | sed 's/cniVersion://g')
    if [[ -z $CNI_NAM ]]; then
        CNI_NAM="false"
        CNI_VER="0"
    fi
}

# Per Cluster totals
function total_up_data() {
    DISK_SIZE=0
    DISK_USED=0
    MEM_SIZE=0
    MEM_USED=0
    while IFS="" read -r line || [ -n "$line" ]; do
        NEW_DISK_SIZE=$(echo $line | awk '{print $2}' | numfmt --from=iec)
        DISK_SIZE=$((DISK_SIZE + NEW_DISK_SIZE))

        NEW_DISK_USED=$(echo $line | awk '{print $3}' | sed 's/([^)]*)//g' | numfmt --from=iec)
        DISK_USED=$((DISK_USED + NEW_DISK_USED))

        NEW_MEM_SIZE=$(echo $line | awk '{print $4}' | numfmt --from=iec)
        MEM_SIZE=$((MEM_SIZE + NEW_MEM_SIZE))

        NEW_MEM_USED=$(echo $line | awk '{print $5}' | sed 's/([^)]*)//g' | numfmt --from=iec)
        MEM_USED=$((MEM_USED + NEW_MEM_USED))
    done </home/astrolabe.pernode_table

    DISK_SIZE=$(echo ${DISK_SIZE} | numfmt --to=iec --format %f)
    DISK_USED=$(echo ${DISK_USED} | numfmt --to=iec --format %f)
    DISK_SIZE_RAW=$(echo $DISK_SIZE | numfmt --from=iec)
    DISK_USED_RAW=$(echo $DISK_USED | numfmt --from=iec)
    DISK_USED_PERC=$((200 * $DISK_USED_RAW / $DISK_SIZE_RAW % 2 + 100 * $DISK_USED_RAW / $DISK_SIZE_RAW))

    MEM_SIZE=$(echo ${MEM_SIZE} | numfmt --to=iec --format %f)
    MEM_USED=$(echo ${MEM_USED} | numfmt --to=iec --format %f)
    MEM_SIZE_RAW=$(echo $MEM_SIZE | numfmt --from=iec)
    MEM_USED_RAW=$(echo $MEM_USED | numfmt --from=iec)
    MEM_USED_PERC=$((200 * $MEM_USED_RAW / $MEM_SIZE_RAW % 2 + 100 * $MEM_USED_RAW / $MEM_SIZE_RAW))

    echo >>/home/astrolabe.pernode_table_sorted
    printf "$HEADER" "" "---------" "---------" "--------" "--------" >>/home/astrolabe.pernode_table_sorted
    printf "$HEADER" "TOTALS:" "$DISK_SIZE" "$DISK_USED($DISK_USED_PERC%)" "$MEM_SIZE" "$MEM_USED($MEM_USED_PERC%)" >>/home/astrolabe.pernode_table_sorted
    printf "$HEADER" "" "---------" "---------" "--------" "--------" >>/home/astrolabe.pernode_table_sorted
    echo >>/home/astrolabe.pernode_table_sorted
}

function get_node_instances() {
    NODES=$(kubectl get nodes | grep -v NAME | awk '{print $1}')
    for node in "${NODES[@]}"; do
        echo "$node"
    done
}

function get_k8s_vers() {
    export CLIENT=$(kubectl version --short 2>/dev/null | grep 'Client Version' | awk '{print $3}')
    export SERVER=$(kubectl version --short 2>/dev/null | grep 'Server Version' | awk '{print $3}')
}

function get_sas_info() {
    export NAMESPACE=$(kubectl get namespace --no-headers | grep -v 'astrolabe' | grep -v 'cert-' | grep -v 'default' | grep -v 'ingress' | grep -v 'kube-' | grep -v 'nfs-client' | grep -v 'lens-' | grep -v 'kubecost' | awk '{print $1;}')
    if [[ -z $NAMESPACE ]]; then
        NAMESPACE="false"
        return
    fi

    SAS_CADENCE=$(kubectl -n $NAMESPACE get cm -o yaml | grep ' SAS_CADENCE_')

    SAS_CADENCE_DISPLAY_SHORT_NAME=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_DISPLAY_SHORT_NAME' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_DISPLAY_SHORT_NAME=${SAS_CADENCE_DISPLAY_SHORT_NAME//\"/}

    SAS_CADENCE_DISPLAY_VERSION=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_DISPLAY_VERSION' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_DISPLAY_VERSION="${SAS_CADENCE_DISPLAY_VERSION/\//_}"

    SAS_CADENCE_RELEASE=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_RELEASE' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_RELEASE=${SAS_CADENCE_RELEASE//\"/}

    SAS_CADENCE_VERSION=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_VERSION' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_VERSION=${SAS_CADENCE_VERSION//\"/}
}

function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

    case $1 in
    start)
        # calculate the column where spinner and status msg will be displayed
        let column=$(tput cols)-${#2}-8
        # display message and position the cursor in $column column
        echo -en ${CYAN}${2}
        echo -en ${NC}
        printf "%${column}s"

        # start spinner
        i=1
        sp='\|/-'
        delay=${SPINNER_DELAY:-0.15}

        while :; do
            printf "\b${sp:i++%${#sp}:1}"
            sleep $delay
        done
        ;;
    stop)
        if [[ -z ${3} ]]; then
            echo "spinner is not running.."
            exit 1
        fi

        kill $3 >/dev/null 2>&1

        # Inform the user upon success or failure
        echo -en "\b["
        if [[ $2 -eq 0 ]]; then
            echo -en "${green}${on_success}${nc}"
        else
            echo -en "${red}${on_fail}${nc}"
        fi
        echo -e "]"
        ;;
    *)
        echo "invalid argument, try {start/stop}"
        exit 1
        ;;
    esac
}

function start_spinner() {
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
    # use sleep to give spinner time to fork and run
    # because cp fails instantly
    sleep 1
    echo
}

function stop_spinner() {
    # $1 : command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

if [[ "$PRETTY" == "true" ]]; then
    clear
    echo
    echo "----Astrolabe----Astrolabe----Astrolabe----Astrolabe----Astrolabe----Astrolabe----Astrolabe----" >/home/astrolabe.start
    echo >>/home/astrolabe.start
    echo "Retrieve and display data: CPU, MEM and Cost about Cluster: '$CLUSTER_NAME'..." >>/home/astrolabe.start
    echo >>/home/astrolabe.start
fi

if [[ "$VERBOSE" != "false" ]]; then
    echo "Verbose=$VERBOSE" >>/home/astrolabe.start
    echo "" >>/home/astrolabe.start
fi
if [[ "$PRETTY" == "true" ]]; then
    echo "Add: -e VERBOSE='v' or 'vv' for more levels of verbosity" >>/home/astrolabe.start
    echo "     -e KUBECOST='true' to enable and see cost information" >>/home/astrolabe.start
    echo "" >>/home/astrolabe.start
    echo "Recomended Alias's:" >>/home/astrolabe.start
    echo ' alias astro="docker run -it --rm -v ${HOME}/.kube/:/root/.kube rwellum/astrolabe:latest"' >>/home/astrolabe.start
    echo ' alias astrov="docker run -it --rm -v ${HOME}/.kube/:/root/.kube -e VERBOSE='v' rwellum/astrolabe:latest"' >>/home/astrolabe.start
    echo ' alias astrovv="docker run -it --rm -v ${HOME}/.kube/:/root/.kube -e VERBOSE='vv' rwellum/astrolabe:latest"' >>/home/astrolabe.start
fi
echo -en ${GREEN}
if [[ "$PRETTY" == "true" ]]; then
    cat /home/astrolabe.start | boxes -d peek -p a2v1
fi
echo -en ${NC}
echo

if [[ "$VERBOSE" = "vv" ]]; then
    #
    # List all installed kubectl plugins
    #
    echo "Krew: installed plugins" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl krew list >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # Describe nodes which has useful resource information
    #
    echo "describe nodes: All node resources" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl describe nodes >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d stone -p a2v1
    echo -en ${NC}
    echo

    #
    # look at allocated resources
    #
    echo "view-allocations: Allocated resources across this cluster:" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl view-allocations >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # look at allocated resources - similar and maybe overlapping
    #
    echo "resource-capacity: total CPU and Memory resource requests and limits for all the pods" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl resource-capacity --pods --sort mem.util --containers --util >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # CPU and Memory utilizations, split into namespace and nodes
    #
    echo "view-utilization: Total Utilization of this Cluster:" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl view-utilization >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    echo "view-utilization: Overview of namespace utilization" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl view-utilization namespaces -h >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    echo "view-utilization: Breakdown of node utilization" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl view-utilization nodes -h >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # Resource utilization using the metrics server
    #
    echo "view-utilization: Total Utilization of this Cluster (Human):" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl view-utilization -h >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # Popeye - look for problems
    # Too much useles info for now
    # echo "Popeye: look for problems" | boxes -d columns -p a2v1
    # echo
    # kubectl popeye
    # echo

    #
    # look at resource snapshot
    #
    echo "resource-snapshot: Snapshot of resources:" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl resource-snapshot -print nodes >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # List Taints on Nodes
    #
    echo "List taints on nodes:" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints[*].key}{"\n"}{end}' >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # Show label on pods - very verbose
    #
    echo "Show pods and their labels:" >/home/astrolabe.verbose
    echo >>/home/astrolabe.verbose
    kubectl get pods --show-labels --all-namespaces >>/home/astrolabe.verbose
    echo -en ${GREEN}
    cat /home/astrolabe.verbose | boxes -d columns -p a2v1
    echo -en ${NC}
    echo
fi

#
# v or vv
#
if [[ "$VERBOSE" = "v" ]] || [[ "$VERBOSE" = "vv" ]]; then
    #
    # Get nodes
    #
    echo
    echo "Nodes Status:" >/home/astrolabe.nodes
    echo >>/home/astrolabe.nodes
    kubectl get nodes >>/home/astrolabe.nodes
    echo -en ${GREEN}
    cat /home/astrolabe.nodes | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # Get which pods live on which nodes
    #
    echo
    echo "Nodes to Pods:" >/home/astrolabe.pods
    echo >>/home/astrolabe.pods
    kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name --all-namespaces >>/home/astrolabe.pods
    echo -en ${GREEN}
    cat /home/astrolabe.pods | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # Resource utilization - relies on working metrics server
    #
    echo "Nodes Resource Utilization (metrics server):" >/home/astrolabe.metrics
    echo >>/home/astrolabe.metrics
    kubectl resource-capacity --util >>/home/astrolabe.metrics
    echo -en ${GREEN}
    cat /home/astrolabe.metrics | boxes -d columns -p a2v1
    echo -en ${NC}
    echo

    #
    # Top nodes - relies on working metrics server
    #
    echo
    echo "Nodes CPU and Memory (metrics server):" >/home/astrolabe.top
    echo >>/home/astrolabe.top
    kubectl top nodes --use-protocol-buffers >>/home/astrolabe.top
    echo -en ${GREEN}
    cat /home/astrolabe.top | boxes -d columns -p a2v1
    echo -en ${NC}
    echo
fi

#
# Disk and Memory Daemonset
#

# Start a daemonset to all pods and gather the disk usage
if [[ "$PRETTY" == "true" ]]; then
    start_spinner "Deploying Astrolabe Daemonset on Cluster: '${CLUSTER_NAME}'...."
fi
kubectl create namespace astrolabe &>/dev/null
kubectl apply -f disk_use_daemonset.yml &>/dev/null
wait_for_daemonset
if [[ "$PRETTY" == "true" ]]; then
    stop_spinner $?
    start_spinner "Collecting and processing data from Daemonset pods...."
fi
# Send logs to a file for further processing
kubectl logs -l app=disk-checker -n astrolabe --tail=-1 >>/home/astrolabe.pernode

# Display in table form like all other commands
# Kubectl commands can be run from here
# Node specific must be run from the daemonset
while IFS="" read -r line || [ -n "$line" ]; do
    if [[ ! -z "$line" ]]; then
        if [[ $line != *"Size"* ]] && [[ $line != *"Used"* ]] && [[ $line != *"CPU"* ]]; then
            # This line of text it is the vm node line, e.g.:
            # aks-system-30686869-vmss000000
            # With the node name, per node kubectl calls can be made
            NODE=$line
            INST=$(kubectl describe node $NODE | grep node.kubernetes.io/instance-type | cut -f2- -d=)
            LINUX=$(kubectl describe node $NODE | grep 'OS Image:' | sed 's/OS Image://g' | sed -e 's/^[ \t]*//')
            LINUX="${LINUX// /_}"
            CONTAINER_RUNTIME=$(kubectl describe node $NODE | grep 'Container Runtime Version:' | cut -f2- -d: | cut -f1 -d":" | xargs)
            STORAGE_TIER=$(kubectl describe node $NODE | grep 'storagetier=' | xargs | cut -f2- -d=)
            TAINTS=$(kubectl describe node $NODE | grep 'Taints:' | xargs | cut -f2- -d:)
            CPU_PER=$(kubectl top nodes --no-headers --use-protocol-buffers | grep $NODE | awk '{print $3}')
            continue
        elif [[ $line == *"Disk_Size"* ]]; then
            DISK_SIZE=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --from=iec --format %f)
            continue
        elif [[ $line == *"Disk_Used"* ]]; then
            DISK_USED=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --from=iec --format %f)
            continue
        elif [[ $line == *"Mem_Size"* ]]; then
            MEM_SIZE=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --format %f)
            continue
        elif [[ $line == *"Mem_Used"* ]]; then
            MEM_USED=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --format %f)
            continue
        elif [[ $line == *"CPU_Num"* ]]; then
            CPU_NUM=$(cut -d "=" -f2 <<<"$line")
            continue
        elif [[ $line == *"CPU_Threads"* ]]; then
            CPU_THREADS=$(cut -d "=" -f2 <<<"$line")
            continue
        elif [[ $line == *"CPU_Sockets"* ]]; then
            CPU_SOCKETS=$(cut -d "=" -f2 <<<"$line")
            continue
        fi
    fi

    # Percentage used
    DISK_SIZE_RAW=$(echo $DISK_SIZE | numfmt --from=iec)
    DISK_USED_RAW=$(echo $DISK_USED | numfmt --from=iec)
    DISK_USED_PERC=$((200 * $DISK_USED_RAW / $DISK_SIZE_RAW % 2 + 100 * $DISK_USED_RAW / $DISK_SIZE_RAW))

    MEM_SIZE_RAW=$(echo $MEM_SIZE | numfmt --from=iec)
    MEM_USED_RAW=$(echo $MEM_USED | numfmt --from=iec)
    MEM_USED_PERC=$((200 * $MEM_USED_RAW / $MEM_SIZE_RAW % 2 + 100 * $MEM_USED_RAW / $MEM_SIZE_RAW))

    printf "$HEADER" "$NODE" "$DISK_SIZE" "$DISK_USED($DISK_USED_PERC%)" "$MEM_SIZE" "$MEM_USED($MEM_USED_PERC%)" "$INST" "$LINUX" "$CPU_NUM" "$CPU_THREADS" "$CPU_PER" "$CONTAINER_RUNTIME" "$STORAGE_TIER" "$TAINTS" >>/home/astrolabe.pernode_table
done </home/astrolabe.pernode

# Sort the table alphabetically
sort -t$'\t' -k3 -n /home/astrolabe.pernode_table >/home/astrolabe.pernode_table_sorted
total_up_data

# Get K8s version
get_k8s_vers

# Get SAS Specific info
get_sas_info

# Get CNI info
get_cni

# Add header
sed -i "1s/^/----                               ---------  ---------  --------  --------  ---------         -----               ----  ----  ----  -------     -------      ------\n/" /home/astrolabe.pernode_table_sorted
sed -i "1s/^/NODE                               DISK_SIZE  DISK_USED  MEM_SIZE  MEM_USED  INST_TYPE         LINUX               CPUS  THRS  CPU%  RUNTIME     STORAGE      TAINTS\n/" /home/astrolabe.pernode_table_sorted
if [[ "$PRETTY" == "true" ]]; then
    sed -i "1s/^/+----------------------+\n\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/| Per Node information |\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/+----------------------+\n/" /home/astrolabe.pernode_table_sorted
else
    sed -i "1s/^/--------------------\n\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/Per Node information\n/" /home/astrolabe.pernode_table_sorted
fi
if [[ $NAMESPACE != "false" ]]; then
    sed -i "1s/^/SAS Viya4 Release:    Cadence: ${SAS_CADENCE_DISPLAY_SHORT_NAME}, Version: ${SAS_CADENCE_VERSION}, Date.Epoch: ${SAS_CADENCE_RELEASE}\n\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/SAS Viya4 Namespace:  ${NAMESPACE}\n/" /home/astrolabe.pernode_table_sorted
fi

if [[ $CNI_NAM != "false" ]]; then
    sed -i "1s/^/Networking:           CNI: ${CNI_NAM}, CNI Version: ${CNI_VER}\n/" /home/astrolabe.pernode_table_sorted
fi

if [[ $NAMESPACE != "false" ]]; then
    sed -i "1s/^/K8s Versions:         Client: ${CLIENT}, Server: ${SERVER}\n/" /home/astrolabe.pernode_table_sorted
else
    sed -i "1s/^/K8s Versions:         Client: ${CLIENT}, Server: ${SERVER}\n\n/" /home/astrolabe.pernode_table_sorted
fi
sed -i "1s/^/Cluster Name:         ${CLUSTER_NAME}\n/" /home/astrolabe.pernode_table_sorted
if [[ "$PRETTY" == "true" ]]; then
    sed -i "1s/^/+------------------------+\n\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/| Deployment information |\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/+------------------------+\n/" /home/astrolabe.pernode_table_sorted
else
    sed -i "1s/^/----------------------\n\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/Deployment information\n/" /home/astrolabe.pernode_table_sorted
fi
if [[ "$PRETTY" == "true" ]]; then
    sed -i "1s/^/----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----\n\n/" /home/astrolabe.pernode_table_sorted
    stop_spinner $?
fi

# Cleanup daemonset
if [[ "$PRETTY" == "true" ]]; then
    start_spinner 'Destroying Astrolabe Daemonset....'
fi
kubectl delete daemonset disk-checker -n astrolabe &>/dev/null
wait_for_daemonset_to_die
if [[ "$PRETTY" == "true" ]]; then
    stop_spinner $?
fi
# Get PVC info
get_pv_info

# Grab some Top Pods info
get_top_pods

# Deploy Kubecost and show some outputs
enable_kubecost

if [[ "$PRETTY" == "true" ]]; then
    start_spinner 'Getting Cost data....'
fi
get_kubecost_data
if [[ "$PRETTY" == "true" ]]; then
    stop_spinner $?
fi

# Display data
if [[ "$PRETTY" == "true" ]]; then
    sleep 3
    echo -e "${CYAN}Displaying data....${NC}"
    sleep 1
    echo
    echo -en ${GREEN}
    cat /home/astrolabe.pernode_table_sorted | boxes -d columns -p a2v1
    echo -en ${NC}
else
    cat /home/astrolabe.pernode_table_sorted
fi

#Destroy kubecost deployment
#kubectl delete namespace kubecost &>/dev/null
