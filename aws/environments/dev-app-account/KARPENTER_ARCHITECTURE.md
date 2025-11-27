# Karpenter Architecture - System vs Application Nodes

## 🏗️ **Architecture Overview**

When using Karpenter, the EKS cluster has **two types of nodes**:

### **1. System Nodes (Managed Node Group)**
- **Purpose**: Run Karpenter controller and critical system components
- **Size**: 2x t3.small (on-demand)
- **Managed by**: EKS Managed Node Groups
- **Tainted**: `CriticalAddonsOnly=true:NoSchedule`
- **Runs**:
  - Karpenter controller
  - CoreDNS
  - AWS Load Balancer Controller
  - Metrics Server
  - Other system add-ons

### **2. Application Nodes (Karpenter-Managed)**
- **Purpose**: Run all application workloads
- **Size**: Dynamically provisioned by Karpenter
- **Managed by**: Karpenter
- **Instance Types**: t3.medium, t3a.medium (configurable)
- **Capacity**: SPOT instances with on-demand fallback
- **Runs**:
  - Your application pods
  - User workloads
  - Batch jobs

---

## ❌ **Common Mistake: Mixing Managed Node Groups + Karpenter**

### **WRONG** ❌
```hcl
node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "SPOT"
    min_size       = 2
    max_size       = 10  # This competes with Karpenter!
  }
}

enable_karpenter = true  # Both will try to create nodes!
```

**Problem**: 
- Managed node group creates 2-10 nodes
- Karpenter ALSO creates nodes for pending pods
- Result: Double the nodes you need, wasted money!

### **CORRECT** ✅
```hcl
node_groups = {
  karpenter-system = {
    instance_types = ["t3.small"]
    capacity_type  = "ON_DEMAND"
    min_size       = 2
    max_size       = 2  # Fixed size, just for system
    
    taints = [{
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NoSchedule"  # Only system pods can schedule here
    }]
  }
}

enable_karpenter = true  # Karpenter manages ALL application nodes
```

**Benefits**:
- System nodes are stable and small
- Karpenter has full control over application nodes
- No conflicts or duplicate nodes
- Maximum cost optimization

---

## 🎯 **How It Works**

### **Cluster Startup:**
1. EKS creates 2x t3.small system nodes (managed node group)
2. System components (Karpenter, CoreDNS, etc.) start on system nodes
3. Karpenter controller is now running

### **Application Deployment:**
1. You deploy your application: `kubectl apply -f app.yaml`
2. Pods are pending (no nodes available)
3. **Karpenter detects pending pods**
4. Karpenter provisions optimal nodes (e.g., 2x t3.medium SPOT)
5. Pods schedule on Karpenter-managed nodes

### **Scaling Up:**
1. More pods are deployed
2. Karpenter provisions more nodes as needed
3. Respects NodePool limits (CPU, memory)

### **Scaling Down:**
1. Pods are deleted or scaled down
2. Karpenter detects underutilized nodes
3. After consolidation delay (30-60s), Karpenter:
   - Moves remaining pods to other nodes
   - Terminates empty/underutilized nodes
4. Cost savings!

---

## 📊 **Node Distribution Example**

### **Dev Environment:**
```
System Nodes (Managed):
├── node-1 (t3.small, on-demand) - Karpenter controller, CoreDNS
└── node-2 (t3.small, on-demand) - AWS LB Controller, Metrics Server

Application Nodes (Karpenter):
├── node-3 (t3.medium, SPOT) - App pods
├── node-4 (t3.medium, SPOT) - App pods
└── (scales 0-∞ based on demand)
```

### **Production Environment:**
```
System Nodes (Managed):
├── node-1 (t3.small, on-demand) - Karpenter, CoreDNS
└── node-2 (t3.small, on-demand) - System components

Application Nodes (Karpenter):
├── General Purpose NodePool (SPOT):
│   ├── node-3 (t3.medium, SPOT, AZ-a)
│   ├── node-4 (t3.medium, SPOT, AZ-b)
│   └── node-5 (t3.medium, SPOT, AZ-c)
│
└── Critical Workloads NodePool (On-Demand):
    ├── node-6 (t3.medium, on-demand, AZ-a) - Database pods
    └── node-7 (t3.medium, on-demand, AZ-b) - Critical services
```

---

## 🔍 **Verifying Your Setup**

### **Check System Nodes:**
```bash
kubectl get nodes -l workload=system

# Should show 2 nodes (t3.small, on-demand)
```

### **Check Karpenter-Managed Nodes:**
```bash
kubectl get nodes -l karpenter.sh/provisioner-name

# Shows nodes created by Karpenter for your apps
```

### **Check Node Taints:**
```bash
kubectl describe node <system-node-name> | grep Taints

# Should show: CriticalAddonsOnly=true:NoSchedule
```

### **Verify Karpenter is Running:**
```bash
kubectl get pods -n karpenter

# Should show karpenter controller running on system nodes
```

---

## 💰 **Cost Comparison**

### **Scenario: 10 application pods needing t3.medium**

#### **Without Karpenter (Managed Node Groups):**
```
System + Application in one node group:
- 5x t3.medium on-demand = $150/month
- Always running, even if only 2 pods active
```

#### **With Karpenter (Correct Setup):**
```
System nodes:
- 2x t3.small on-demand = $15/month

Application nodes (Karpenter):
- 3x t3.medium SPOT (when needed) = $13.50/month
- Scales to 0 when no workload = $0/month

Average: $15 + $13.50 = $28.50/month
Savings: $121.50/month (81%!)
```

---

## ✅ **Best Practices**

1. **Keep system node group small and stable**
   - 2-3 nodes maximum
   - t3.small or t3.medium
   - Always on-demand (never SPOT)

2. **Let Karpenter manage all application nodes**
   - No additional managed node groups
   - Configure NodePools for different workload types
   - Use taints/tolerations for workload isolation

3. **Use Pod Disruption Budgets**
   - Protect critical applications during Spot interruptions
   - Ensure high availability during consolidation

4. **Monitor Karpenter behavior**
   - Watch logs: `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter`
   - Track node provisioning and consolidation
   - Adjust NodePool limits as needed

---

## 🚨 **Troubleshooting**

### **Pods not scheduling?**
- Check if they have tolerations for system node taints
- Verify Karpenter NodePool limits aren't exceeded
- Check Karpenter logs for errors

### **Too many nodes?**
- Verify you don't have competing managed node groups
- Check consolidation settings in NodePool
- Review pod resource requests (over-requesting causes more nodes)

### **System pods on Karpenter nodes?**
- System pods should have tolerations for `CriticalAddonsOnly` taint
- Karpenter controller must run on system nodes
- Check pod nodeSelector/affinity rules

---

## 📚 **Further Reading**

- [Karpenter Best Practices](https://karpenter.sh/docs/concepts/nodepools/)
- [EKS Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [Kubernetes Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
