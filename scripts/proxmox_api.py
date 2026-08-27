#!/usr/bin/env python3
"""
proxmox_api.py — Python wrapper for Proxmox VE API
Simple client for managing VMs, LXC containers, storage, and nodes
"""

import urllib.request
import urllib.parse
import json
import logging
from typing import Optional, List, Dict, Any

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


class ProxmoxAPI:
    """Proxmox VE API client"""
    
    def __init__(self, host: str, user: str, token: str, verify_ssl: bool = False):
        self.host = host
        self.user = user
        self.token = token
        self.verify_ssl = verify_ssl
        self.base_url = f"https://{host}:8006/api2/json"
        self.auth_header = f"PVEAPIToken={token}"
    
    def _request(self, method: str, endpoint: str, data: Optional[dict] = None) -> Optional[Dict]:
        """Make API request"""
        url = f"{self.base_url}{endpoint}"
        
        try:
            headers = {
                "Authorization": self.auth_header,
                "Content-Type": "application/x-www-form-urlencoded"
            }
            
            body = None
            if data:
                body = urllib.parse.urlencode(data).encode()
            
            req = urllib.request.Request(
                url, data=body, headers=headers, method=method
            )
            
            context = None
            if not self.verify_ssl:
                import ssl
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
            
            with urllib.request.urlopen(req, context=context, timeout=30) as resp:
                return json.loads(resp.read().decode())
        except Exception as e:
            logger.error(f"API request failed: {e}")
            return None
    
    # Node operations
    def get_nodes(self) -> List[Dict]:
        """Get all nodes"""
        result = self._request("GET", "/nodes")
        return result.get("data", []) if result else []
    
    def get_node_status(self, node: str) -> Dict:
        """Get node status"""
        result = self._request("GET", f"/nodes/{node}/status")
        return result.get("data", {}) if result else {}
    
    # VM operations
    def get_vms(self, node: str) -> List[Dict]:
        """Get all VMs on a node"""
        result = self._request("GET", f"/nodes/{node}/qemu")
        return result.get("data", []) if result else []
    
    def get_vm_status(self, node: str, vmid: int) -> Dict:
        """Get VM status"""
        result = self._request("GET", f"/nodes/{node}/qemu/{vmid}/status/current")
        return result.get("data", {}) if result else {}
    
    def start_vm(self, node: str, vmid: int) -> bool:
        """Start VM"""
        result = self._request("POST", f"/nodes/{node}/qemu/{vmid}/status/start")
        return result is not None
    
    def stop_vm(self, node: str, vmid: int) -> bool:
        """Stop VM"""
        result = self._request("POST", f"/nodes/{node}/qemu/{vmid}/status/stop")
        return result is not None
    
    def shutdown_vm(self, node: str, vmid: int) -> bool:
        """Graceful shutdown VM"""
        result = self._request("POST", f"/nodes/{node}/qemu/{vmid}/status/shutdown")
        return result is not None
    
    def create_vm(self, node: str, vmid: int, name: str, **kwargs) -> bool:
        """Create new VM"""
        data = {"vmid": vmid, "name": name, **kwargs}
        result = self._request("POST", f"/nodes/{node}/qemu", data)
        return result is not None
    
    def delete_vm(self, node: str, vmid: int, purge: bool = True) -> bool:
        """Delete VM"""
        params = {"purge": "1" if purge else "0"}
        result = self._request("DELETE", f"/nodes/{node}/qemu/{vmid}?purge={'1' if purge else '0'}")
        return result is not None
    
    # LXC operations
    def get_lxcs(self, node: str) -> List[Dict]:
        """Get all LXC containers on a node"""
        result = self._request("GET", f"/nodes/{node}/lxc")
        return result.get("data", []) if result else []
    
    def get_lxc_status(self, node: str, vmid: int) -> Dict:
        """Get LXC status"""
        result = self._request("GET", f"/nodes/{node}/lxc/{vmid}/status/current")
        return result.get("data", {}) if result else {}
    
    def start_lxc(self, node: str, vmid: int) -> bool:
        """Start LXC"""
        result = self._request("POST", f"/nodes/{node}/lxc/{vmid}/status/start")
        return result is not None
    
    def stop_lxc(self, node: str, vmid: int) -> bool:
        """Stop LXC"""
        result = self._request("POST", f"/nodes/{node}/lxc/{vmid}/status/stop")
        return result is not None
    
    def create_lxc(self, node: str, vmid: int, **kwargs) -> bool:
        """Create new LXC container"""
        data = {"vmid": vmid, **kwargs}
        result = self._request("POST", f"/nodes/{node}/lxc", data)
        return result is not None
    
    # Backup operations
    def get_backup_jobs(self, node: str) -> List[Dict]:
        """Get backup jobs"""
        result = self._request("GET", f"/nodes/{node}/vzdump")
        return result.get("data", []) if result else []
    
    def create_backup(self, node: str, vmid: int, storage: str, mode: str = "snapshot", 
                      compress: str = "zstd") -> bool:
        """Create backup of VM/LXC"""
        data = {
            "vmid": vmid,
            "storage": storage,
            "mode": mode,
            "compress": compress
        }
        result = self._request("POST", f"/nodes/{node}/vzdump", data)
        return result is not None
    
    # Storage
    def get_storages(self, node: str) -> List[Dict]:
        """Get all storages"""
        result = self._request("GET", f"/nodes/{node}/storage")
        return result.get("data", []) if result else []
    
    # Tasks
    def get_tasks(self, node: str) -> List[Dict]:
        """Get running tasks"""
        result = self._request("GET", f"/nodes/{node}/tasks")
        return result.get("data", []) if result else []


# Example usage
if __name__ == "__main__":
    import os
    
    host = os.environ.get("PROXMOX_HOST", "localhost")
    user = os.environ.get("PROXMOX_USER", "root@pam")
    token = os.environ.get("PROXMOX_TOKEN")
    
    if not token:
        print("Set PROXMOX_TOKEN environment variable")
        exit(1)
    
    api = ProxmoxAPI(host, user, token)
    
    # List nodes
    nodes = api.get_nodes()
    print(f"Nodes: {[n['node'] for n in nodes]}")
    
    # For each node, list VMs and LXCs
    for node_info in nodes:
        node = node_info["node"]
        vms = api.get_vms(node)
        lxcs = api.get_lxcs(node)
        
        print(f"\n=== Node: {node} ===")
        print(f"  VMs: {len(vms)}")
        for vm in vms:
            print(f"    {vm['vmid']}: {vm['name']} ({vm['status']})")
        
        print(f"  LXCs: {len(lxcs)}")
        for lxc in lxcs:
            print(f"    {lxc['vmid']}: {lxc['name']} ({lxc['status']})")