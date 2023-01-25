#!/usr/bin/env bash

# 设置各变量
WSPATH=neu  # WS 路径前缀。(注意:伪装路径不需要 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
UUID=10974d1a-cbd6-4b6f-db1d-38d78b3fb109
# NEZHA_SERVER=server.nezha.org # 哪吒三个参数，不需要的话可以留空，删除或在这三行最前面加 # 以注释
# NEZHA_PORT=5555
# NEZHA_KEY=olx2IwyG7BZjylaW3H

# 安装系统依赖
check_dependencies() {
  DEPS_CHECK=("wget" "unzip")
  DEPS_INSTALL=(" wget" " unzip")
  for ((i=0;i<${#DEPS_CHECK[@]};i++)); do [[ ! $(type -p ${DEPS_CHECK[i]}) ]] && DEPS+=${DEPS_INSTALL[i]}; done
  [ -n "$DEPS" ] && { apt-get update >/dev/null 2>&1; apt-get install -y $DEPS >/dev/null 2>&1; }
}

generate_config() {
  cat > config.json << EOF
{
    "log":{
        "access":"/dev/null",
        "error":"/dev/null",
        "loglevel":"none"
    },
    "inbounds":[
        {
            "port":8080,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "flow":"xtls-rprx-direct"
                    }
                ],
                "decryption":"none",
                "fallbacks":[
                    {
                        "dest":3001
                    },
                    {
                        "path":"/${WSPATH}-vless",
                        "dest":3002
                    },
                    {
                        "path":"/${WSPATH}-vmess",
                        "dest":3003
                    },
                    {
                        "path":"/${WSPATH}-trojan",
                        "dest":3004
                    },
                    {
                        "path":"/${WSPATH}-shadowsocks",
                        "dest":3005
                    }
                ]
            },
            "streamSettings":{
                "network":"tcp"
            }
        },
        {
            "port":3001,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none"
            }
        },
        {
            "port":3002,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":0,
                        "email":"argo@xray"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-vless"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3003,
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-vmess"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3004,
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"${UUID}"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-trojan"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3005,
            "listen":"127.0.0.1",
            "protocol":"shadowsocks",
            "settings":{
                "clients":[
                    {
                        "method":"chacha20-ietf-poly1305",
                        "password":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-shadowsocks"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        }
    ],
    "dns":{
        "servers":[
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds":[
        {
            "protocol":"freedom"
        }
    ]
}
EOF
}

generate_argo() {
  cat > argo.sh << ABC
  #!/usr/bin/env bash

  # 下载并运行 Argo
  [ ! -e cloudflared-linux-amd64 ] && wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared-linux-amd64
  if [[ -e cloudflared-linux-amd64 && ! \$(ps -ef) =~ cloudflared-linux-amd64 ]]; then
    ./cloudflared-linux-amd64 tunnel --url http://localhost:${PORT} --no-autoupdate > argo.log 2>&1 &
    sleep 15
    ARGO=\$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##")
    cat > list << EOF
vless://${UUID}@www.digitalocean.com:443?encryption=none&security=tls&type=ws&host=\${ARGO}&path=/${WSPATH}-vless&sni=\${ARGO}#Argo-Vless
===============================================================================
- {name: Argo-Vless, type: vless, server: www.digitalocean.com, port: 443, uuid: ${UUID}, tls: true, servername: \${ARGO}, skip-cert-verify: false, network: ws, ws-opts: {path: /${WSPATH}-vless, headers: { Host: \${ARGO}}}, udp: true}
===============================================================================
vmess://$(echo "none:${UUID}@www.digitalocean.com:443" | base64 -w0)?remarks=Argo-Vmess&obfsParam=\${ARGO}&path=/${WSPATH}-vmess&obfs=websocket&tls=1&peer=\${ARGO}&alterId=0
===============================================================================
- {name: Argo-Vmess, type: vmess, server: www.digitalocean.com, port: 443, uuid: ${UUID}, alterId: 0, cipher: none, tls: true, skip-cert-verify: true, network: ws, ws-opts: {path: /${WSPATH}-vmess, headers: {Host: \${ARGO}}}, udp: true}
===============================================================================
trojan://${UUID}@www.digitalocean.com:443?peer=\${ARGO}&plugin=obfs-local;obfs=websocket;obfs-host=\${ARGO};obfs-uri=/${WSPATH}-trojan#Argo-Trojan
===============================================================================
- {name: Argo-Trojan, type: trojan, server: www.digitalocean.com, port: 443, password: ${UUID}, udp: true, tls: true, sni: \${ARGO}, skip-cert-verify: false, network: ws, ws-opts: { path: /${WSPATH}-trojan, headers: { Host: \${ARGO} } } }
===============================================================================
ss://$(echo "chacha20-ietf-poly1305:${UUID}@www.digitalocean.com:443" | base64 -w0)?obfs=wss&obfsParam=\${ARGO}&path=/${WSPATH}-shadowsocks#Argo-Shadowsocks
===============================================================================
- {name: Argo-Shadowsocks, type: ss, server: www.digitalocean.com, port: 443, cipher: chacha20-ietf-poly1305, password: ${UUID}, plugin: v2ray-plugin, plugin-opts: { mode: websocket, host: \${ARGO}, path: /${WSPATH}-shadowsocks, tls: true, skip-cert-verify: false, mux: false } }
EOF
  cat list
  fi
ABC
}

generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 哪吒的三个参数
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 检测是否已运行
check_run() {
  [[ \$(ps aux) =~ nezha-agent ]] && echo "哪吒客户端正在运行中" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/naiba/nezha/releases/latest" | grep -o "https.*linux_amd64.zip")
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

# 运行客户端
run() {
  [[ ! \$PROCESS =~ nezha-agent && -e nezha-agent ]] && ./nezha-agent -s \${NEZHA_SERVER}:\${NEZHA_PORT} -p \${NEZHA_KEY}
 >/dev/null 2>&1 &
}

check_run
check_variable
download_agent
run
EOF
}

check_dependencies
generate_config
generate_argo
generate_nezha
[ -e nezha.sh ] && bash nezha.sh > /dev/null 2>&1 &
[ -e argo.sh ] && bash argo.sh
