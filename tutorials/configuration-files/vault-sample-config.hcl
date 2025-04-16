############################################################################## 
# Copyright 2021 IBM Corp. All Rights Reserved. 
# 
#  Licensed under the Apache License, Version 2.0 (the "License"); 
#  you may not use this file except in compliance with the License. 
#  You may obtain a copy of the License at 
# 
#       http://www.apache.org/licenses/LICENSE-2.0 
# 
#   Unless required by applicable law or agreed to in writing, software 
#   distributed under the License is distributed on an "AS IS" BASIS, 
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
#   See the License for the specific language governing permissions and 
#   limitations under the License. 
############################################################################## 

# Provide IBM Cloud HPCS connection information 

storage "raft" { 
    path = "/opt/vault/data" 
    node_id = "vault_1"            #setting up a unique node_id for each vault node 
}

# Listener Configuration(TCP) 
listener "tcp" {
    address = "127.0.0.1:8205"
    cluster_address = "127.0.0.1:8206"
    tls_disable = 1
}

# API and Cluster Addresses 
api_addr = "http://127.0.0.1:8205"
cluster_addr = "http://127.0.0.1:8206"

# Enable Vault UI
ui = true 

# Disable mlock
disable_mlock = true

# Enterprise license_path 
# This will be required for enterprise as of v1.8
license_path = "/etc/vault.d/license.hclic" 
