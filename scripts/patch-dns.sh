#!/bin/bash
set -e

echo "Fixing CoreDNS for gitlab.local..."

kubectl get configmap coredns -n kube-system -o json | python3 -c '
import sys, json, re
data = json.load(sys.stdin)
corefile = data["data"]["Corefile"]

target = "ingress-nginx-controller.ingress-nginx.svc.cluster.local"
rule = f"rewrite name gitlab.local {target}"

# Cleanup any existing malformed rule
corefile = re.sub(r"rewrite name gitlab\.local.*", "", corefile)

# Proper insertion after "ready"
if "ready" in corefile:
    corefile = corefile.replace("ready", f"ready\n        {rule}")

data["data"]["Corefile"] = corefile
print(json.dumps(data))
' > coredns-fixed.json

kubectl apply -f coredns-fixed.json
rm coredns-fixed.json
echo "CoreDNS updated and cleaned up."
kubectl rollout restart deployment coredns -n kube-system
echo "CoreDNS restarted."