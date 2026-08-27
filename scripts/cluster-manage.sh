#!/usr/bin/env bash
# cluster-manage.sh — Proxmox VE Cluster Management Tool
# Usage: ./cluster-manage.sh [COMMAND] [OPTIONS]
# Commands: status, health, migrate, list-nodes, join, leave

set -euo pipefail

# Configuration
PROXMOX_HOST="${PROXMOX_HOST:-localhost}"
PROXMOX_USER="${PROXMOX_USER:-root@pam}"
PROXMOX_TOKEN="${PROXMOX_TOKEN:-}"
PROXMOX_VERIFY_SSL="${PROXMOX_VERIFY_SSL:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ${BLUE}$1${NC}"; }
error() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${RED}$1${NC}"; exit 1; }
warn() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] ${YELLOW}$1${NC}"; }
success() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] ${GREEN}$1${NC}"; }

# Build API URL and auth header
BASE_URL="https://${PROXMOX_HOST}:8006/api2/json"
AUTH_HEADER="Authorization: PVEAPIToken=${PROXMOX_TOKEN}"
CURL_OPTS=(-s -H "$AUTH_HEADER" -H "Content-Type: application/x-www-form-urlencoded")
[[ "$PROXMOX_VERIFY_SSL" == "false" ]] && CURL_OPTS+=(-k)

# Check if API token is set
check_auth() {
    if [[ -z "$PROXMOX_TOKEN" ]]; then
        error "PROXMOX_TOKEN environment variable is required"
    fi
}

# Check if cluster is available
check_cluster() {
    local response
    response=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/cluster/status" 2>/dev/null)
    if [[ -z "$response" ]]; then
        error "Cannot connect to Proxmox API. Check PROXMOX_HOST and network connectivity."
    fi
    echo "$response"
}

# Get cluster status
cmd_status() {
    log "Getting cluster status..."
    
    local response
    response=$(check_cluster)
    
    # Parse JSON response
    local quorum=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('quorate', False))")
    local nodes_count=$(echo "$response" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data'].get('nodelist', [])))")
    local node_names=$(echo "$response" | python3 -c "
import sys,json
data = json.load(sys.stdin)['data']
nodes = data.get('nodelist', [])
print(', '.join([n['name'] for n in nodes]))
")
    
    echo ""
    echo "=== Cluster Status ==="
    echo "  Quorum:  $(if [[ "$quorum" == "True" ]]; then echo "${GREEN}Yes${NC}"; else echo "${RED}No${NC}"; fi)"
    echo "  Nodes:   $nodes_count ($node_names)"
    echo ""
    
    # Get detailed node status
    for node in $(echo "$node_names" | tr ',' ' '); do
        local node_status
        node_status=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes/${node}/status" 2>/dev/null)
        local cpu_usage=$(echo "$node_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('cpu', 0))")
        local mem_total=$(echo "$node_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('memory', {}).get('total', 0))")
        local mem_used=$(echo "$node_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('memory', {}).get('used', 0))")
        local uptime=$(echo "$node_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('uptime', 0))")
        
        # Calculate memory percentage
        if [[ "$mem_total" -gt 0 ]]; then
            local mem_percent=$((mem_used * 100 / mem_total))
        else
            local mem_percent=0
        fi
        
        echo "  Node: ${BLUE}${node}${NC}"
        echo "    CPU:    ${cpu_usage}%"
        echo "    Memory: ${mem_used}MB/${mem_total}MB (${mem_percent}%)"
        echo "    Uptime: ${uptime}s"
        echo ""
    done
    
    success "Cluster status retrieved successfully"
}

# Check cluster health
cmd_health() {
    log "Checking cluster health..."
    
    local response
    response=$(check_cluster)
    
    local quorum=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('quorate', False))")
    local nodes=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('nodelist', []))")
    
    # Health check results
    local all_healthy=true
    local issues=()
    
    # Check quorum
    if [[ "$quorum" != "True" ]]; then
        issues+=("Cluster quorum lost")
        all_healthy=false
    fi
    
    # Check each node
    for node in $(echo "$nodes" | python3 -c "import sys,json; nodes=json.load(sys.stdin); print(' '.join([n['name'] for n in nodes]))"); do
        local node_status
        node_status=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes/${node}/status" 2>/dev/null)
        
        if [[ -z "$node_status" ]]; then
            issues+=("Node ${node} unreachable")
            all_healthy=false
            continue
        fi
        
        local cpu=$(echo "$node_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('cpu', 0))")
        local mem_used=$(echo "$node_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('memory', {}).get('used', 0))")
        local mem_total=$(echo "$node_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('memory', {}).get('total', 0))")
        
        # Check for high resource usage
        if [[ "$cpu" -gt 90 ]]; then
            issues+=("Node ${node}: High CPU usage (${cpu}%)")
            all_healthy=false
        fi
        
        if [[ "$mem_total" -gt 0 && "$mem_used" -gt $((mem_total * 90 / 100)) ]]; then
            issues+=("Node ${node}: High memory usage")
            all_healthy=false
        fi
    done
    
    echo ""
    echo "=== Cluster Health Check ==="
    
    if [[ "$all_healthy" == true ]]; then
        echo "  ${GREEN}✓ All checks passed - Cluster is healthy${NC}"
        success "Cluster health check passed"
    else
        echo "  ${RED}✗ Health issues detected:${NC}"
        for issue in "${issues[@]}"; do
            echo "    - ${RED}$issue${NC}"
        done
        error "Cluster health check failed"
    fi
}

# List all nodes in cluster
cmd_list_nodes() {
    log "Listing cluster nodes..."
    
    local response
    response=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        error "Failed to get node list"
    fi
    
    echo ""
    echo "=== Cluster Nodes ==="
    
    local nodes=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'])")
    
    for node in $(echo "$nodes" | python3 -c "import sys,json; nodes=json.load(sys.stdin); print('\n'.join([n['node'] for n in nodes]))"); do
        local node_info
        node_info=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes/${node}/status" 2>/dev/null)
        local cpu=$(echo "$node_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('cpu', 'N/A'))")
        local mem_used=$(echo "$node_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('memory', {}).get('used', 'N/A'))")
        local mem_total=$(echo "$node_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('memory', {}).get('total', 'N/A'))")
        local uptime=$(echo "$node_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('uptime', 'N/A'))")
        
        printf "  ${BLUE}%-20s${NC} CPU: %-5s  Mem: %-12s  Uptime: %ss\n" \
            "$node" "${cpu}%" "${mem_used}MB/${mem_total}MB" "$uptime"
    done
    
    success "Listed ${#nodes} node(s)"
}

# Migrate VM between nodes
cmd_migrate() {
    local vmid=""
    local target_node=""
    local online_migration=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vmid) vmid="$2"; shift 2 ;;
            --target) target_node="$2"; shift 2 ;;
            --online) online_migration=true; shift ;;
            *) error "Unknown option: $1" ;;
        esac
    done
    
    if [[ -z "$vmid" ]]; then
        error "VM ID (--vmid) is required for migration"
    fi
    
    if [[ -z "$target_node" ]]; then
        error "Target node (--target) is required for migration"
    fi
    
    log "Migrating VM $vmid to node $target_node..."
    
    # Get current node for the VM
    local current_node
    current_node=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/cluster/resources" 2>/dev/null | \
        python3 -c "import sys,json; data=json.load(sys.stdin)['data']; print(next((r['node'] for r in data if str(r['vmid'])=='$vmid' and r['type']=='qemu'), ''))")
    
    if [[ -z "$current_node" ]]; then
        error "VM $vmid not found or not a QEMU VM"
    fi
    
    log "Current node: $current_node"
    
    # Check if VM is running
    local vm_status
    vm_status=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes/${current_node}/qemu/${vmid}/status/current" 2>/dev/null)
    local is_running=$(echo "$vm_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('status', '') == 'running')")
    
    # Build migration command
    local migrate_url="${BASE_URL}/nodes/${current_node}/qemu/${vmid}/migrate"
    local migrate_data=("target=${target_node}")
    
    if [[ "$online_migration" == true && "$is_running" == "True" ]]; then
        migrate_data+=("online=1")
        log "Performing online migration..."
    else
        if [[ "$is_running" == "True" ]]; then
            log "VM is running but online migration not requested. VM will be stopped for migration."
        fi
        migrate_data+=("online=0")
    fi
    
    # Execute migration
    local response
    response=$(curl "${CURL_OPTS[@]}" -X POST "$migrate_url" --data-urlencode "$(IFS=\&; echo "${migrate_data[*]}")" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        error "Migration failed"
    fi
    
    # Check migration status
    local task_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data', ''))")
    
    if [[ -n "$task_id" ]]; then
        log "Migration started. Task ID: $task_id"
        
        # Wait for migration to complete
        log "Waiting for migration to complete..."
        local task_status=""
        for i in {1..60}; do
            task_status=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes/${current_node}/tasks/${task_id}/status" 2>/dev/null)
            local status=$(echo "$task_status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('status', ''))")
            
            if [[ "$status" == "OK" ]]; then
                success "VM $vmid migrated successfully to $target_node"
                return
            elif [[ "$status" == "FAILED" ]]; then
                error "Migration failed"
            fi
            sleep 5
        done
        
        error "Migration timeout"
    else
        success "Migration initiated for VM $vmid to $target_node"
    fi
}

# Join cluster (for new nodes)
cmd_join() {
    local node=""
    local cluster_ip=""
    local cluster_name=""
    local password=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --node) node="$2"; shift 2 ;;
            --ip) cluster_ip="$2"; shift 2 ;;
            --name) cluster_name="$2"; shift 2 ;;
            --password) password="$2"; shift 2 ;;
            *) error "Unknown option: $1" ;;
        esac
    done
    
    if [[ -z "$node" || -z "$cluster_ip" ]]; then
        error "Node (--node) and cluster IP (--ip) are required"
    fi
    
    log "Joining node $node to cluster at $cluster_ip..."
    
    # This command would be run on the new node
    local cmd="pvecm add ${cluster_ip} --cluster_name ${cluster_name:-pve} --password ${password:-}"
    
    warn "This operation must be run on the new node ($node) itself."
    warn "Command to execute on $node: $cmd"
    warn "Note: You may need to install pve-cluster package first: apt install pve-cluster"
    
    success "Join command generated. Run it on node $node"
}

# Leave cluster
cmd_leave() {
    local node=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --node) node="$2"; shift 2 ;;
            --force) force=true; shift ;;
            *) error "Unknown option: $1" ;;
        esac
    done
    
    if [[ -z "$node" ]]; then
        error "Node (--node) is required"
    fi
    
    log "Removing node $node from cluster..."
    
    local cmd="pvecm delnode ${node}"
    if [[ "$force" == true ]]; then
        cmd+=" --force"
    fi
    
    warn "This operation must be run on a cluster node."
    warn "Command to execute: $cmd"
    warn "WARNING: This will remove the node from the cluster. Use --force to force removal."
    
    success "Leave command generated. Run it on a cluster node"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Cluster Management Commands:
  status              Show cluster status and node information
  health             Check cluster health (quorum, resource usage)
  list-nodes         List all nodes in the cluster
  migrate --vmid ID --target NODE [--online]
                    Migrate a VM to another node
  join --node NODE --ip IP [--name NAME] [--password PASS]
                    Generate command to join a node to the cluster
  leave --node NODE [--force]
                    Generate command to remove a node from cluster

Common Options:
  --vmid ID           VM ID to operate on
  --target NODE       Target node for migration
  --online            Perform online migration (VM stays running)
  --node NODE         Node name
  --ip IP             Cluster IP address
  --name NAME         Cluster name
  --password PASS     Cluster password
  --force             Force operation

Environment Variables:
  PROXMOX_HOST        Proxmox API host (default: localhost)
  PROXMOX_USER        API user (default: root@pam)
  PROXMOX_TOKEN       API token (format: USER@REALM!TOKENID=TOKENVALUE)
  PROXMOX_VERIFY_SSL  Verify SSL certificate (default: false)

Examples:
  # Check cluster status
  $0 status

  # Check cluster health
  $0 health

  # List all nodes
  $0 list-nodes

  # Migrate VM 100 to node pve2 (online)
  $0 migrate --vmid 100 --target pve2 --online

  # Migrate VM 101 to node pve3 (offline)
  $0 migrate --vmid 101 --target pve3
EOF
}

# Main function
main() {
    check_auth
    
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        status) cmd_status ;;
        health) cmd_health ;;
        list-nodes) cmd_list_nodes ;;
        migrate) cmd_migrate "$@" ;;
        join) cmd_join "$@" ;;
        leave) cmd_leave "$@" ;;
        help|--help|-h) usage ;;
        *) error "Unknown command: $command. Use 'help' for usage." ;;
    esac
}

# Run main function
main "$@"
