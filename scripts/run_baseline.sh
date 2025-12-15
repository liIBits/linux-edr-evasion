#!/bin/bash
echo "baseline test $(date)" > /tmp/baseline.txt
chmod +x /tmp/baseline.txt
cat /tmp/baseline.txt
sha256sum /tmp/baseline.txt
curl -I https://example.com >/dev/null 2>&1
