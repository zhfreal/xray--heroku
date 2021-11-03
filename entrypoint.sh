#!/bin/sh

t_nginx_dir=/etc/nginx
t_nginx_conf=${t_nginx_dir}/nginx.conf
t_nginx_httpd_conf=${t_nginx_dir}/http.d
t_nginx_default_conf=${t_nginx_httpd_conf}/default.conf
t_nginx_www_conf=${t_nginx_httpd_conf}/myserver.conf
t_nginx_httpasswd=${t_nginx_dir}/.httpasswd
t_www_dir=/var/www/demo
t_xray_conf_dir=/etc/xray
t_xray_conf=${t_xray_conf_dir}/config.json
t_xray_bin_dir=/usr/lib/xray
t_demo_zip_file=/demo.zip
t_xray_bin=/usr/bin/xray
t_v2ctl_bin=/usr/bin/v2ctl
t_xray_listen=127.0.0.1
t_xray_port=2333

# App Name
t_appname="${APPNAME:-${AppName}}"
# vmess uuid
t_uuid="${UUID}"
# websocket path for xray transport, 
t_stream_ws_path="${WS_PATH:-${V2_PATH:-${V2_Path}}}"
# specific version for xray, "latest" as default
t_ver="${VER}"

# gen QR or not, {yes|no} or {1|0}
# yes or 1 <==> we should generate QR and config text for share
# no  or 0 <==> we don't generate QR and config text for share
t_gen_qr="${GENQR:-${GenQR}}"
# path store QR and config text
t_share_qr_path="${SHARE_QR_PATH:-${V2_QR_PATH:-${V2_QR_Path}}}"
# user and password for access control for QR path
t_auth_user="${AUTH_USER:-${ADMIN_USER}}"
t_auth_password="${AUTH_PASSWORD:-${ADMIN_PASSWORD}}"

# port for http, get from env which generate by heroku
t_http_port=${PORT}

# set new t_xray_port if PORT is 2333
if [ "${t_http_port}" = "${t_xray_port}" ]; then
    t_xray_port=3333
fi

#remove the leading "/" from WS_PATH and SHARE_QR_PATH
t_stream_ws_path=$(echo "${t_stream_ws_path}" | sed 's/^\/*//')
t_share_qr_path=$(echo "${t_share_qr_path}" | sed 's/^\/*//')

# actual location for qr
t_www_qr_dir=${t_www_dir}/${t_share_qr_path}

# work location for nginx, need for nginx startup
t_nginx_work_dir=/var/lib/nginx

strip_str() {
    echo "$1" | sed 's/^\s*//' | sed 's/\s*$//'
}

# parameter check
# APPNAME
t_appname=$(strip_str "${t_appname}")
if [ -z "${t_appname}" ]; then
    echo "Please set \"APPNAME\"!"
    exit 1
fi
# UUID
t_uuid=$(strip_str "${t_uuid}")
if [ -z "${t_uuid}" ]; then
    # echo "Please set \"UUID\"!"
    # exit 1
    ## generate uuid
    t_uuid=$(uuidgen -r | tr -d "\n")
fi
# WS_PATH
t_stream_ws_path=$(strip_str "${t_stream_ws_path}")
if [ -z "${t_stream_ws_path}" ]; then
    echo "Please set \"WS_PATH\"!"
    exit 1
fi
# VER
t_ver=$(strip_str "${t_ver}")
if [ -z "${t_ver}" ]; then
    echo "Please set \"VER\"!"
    exit 1
fi
# GENQR
t_gen_qr=$(strip_str "${t_gen_qr}" | tr '[A-Z]' '[a-z]')
t_share_qr_path=$(strip_str "${t_share_qr_path}")
t_auth_user=$(strip_str "${t_auth_user}")
t_auth_password=$(strip_str "${t_auth_password}")
if echo "${t_gen_qr}" | grep -E '^(yes|1)$' > /dev/null; then
    t_gen_qr=1
    # SHARE_QR_PATH
    if [ -z "${t_share_qr_path}" ]; then
        echo "Please set \"SHARE_QR_PATH\"!"
        exit 1
    fi
    ### we can have no access control while generate share info
    # AUTH_USER
    # if [ -z "${t_auth_user}" ]; then
    #     echo "Please set \"AUTH_USER\"!"
    #     exit 1
    # fi
    # # AUTH_PASSWORD
    # if [ -z "${t_auth_password}" ]; then
    #     echo "Please set \"AUTH_PASSWORD\"!"
    #     exit 1
    # fi
elif echo "${t_gen_qr}" | grep -E '^(no|0)$' > /dev/null; then
    t_gen_qr=0
else
    echo "Please set \"GENQR\"!"
    exit 1
fi

# 
if [ "${t_share_qr_path}" = "${t_stream_ws_path}" ]; then
    echo "\"WS_PATH\" and \"SHARE_QR_PATH\" should not be the same"
    exit 1
fi

[ -d ${t_www_dir} ] ||  mkdir -p ${t_www_dir}
[ -d ${t_www_qr_dir} ] || mkdir -p ${t_www_qr_dir}
[ -d ${t_xray_bin_dir} ] || mkdir -p ${t_xray_bin_dir}
[ -d ${t_xray_conf_dir} ] || mkdir -p ${t_xray_conf_dir}
[ -d ${t_nginx_work_dir} ] || mkdir -p ${t_nginx_work_dir}

t_share_file=${t_www_qr_dir}/index.html
t_qr_file=${t_www_qr_dir}/xray.png


SYS_Bit="$(getconf LONG_BIT)"

if uname -a | grep 'x86_64' > /dev/null 2>&1; then
    echo -n 
else
    echo "Can't support this ARCH"
    uname -a
    exit 1
fi

if echo ${t_ver} | grep -E '^[v|V]' > /dev/null; then
    t_v2_ver=$(echo ${t_ver} | sed 's/^V/v/')
elif echo $t_ver | grep -E '^[1-9][0-9]*' > /dev/null; then
    t_v2_ver=v${t_ver}
fi

t_url=
if echo ${t_v2_ver} | grep -E '^v' > /dev/null; then
    t_url=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/releases | jq -r --indent 4 '.[].assets[].browser_download_url' | grep "${t_v2_ver}" | grep -E "linux-64.zip$" 2>/dev/null)
fi
if [ "${t_ver}" = "latest" ] || [ -z "${t_url}" ]; then
    t_v2_ver=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/releases | jq ".[0].tag_name" | tr -d '"')
    t_url=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/releases | jq -r --indent 4 '.[0].assets[].browser_download_url'  | grep -E "linux-64.zip$")
else
    t_v2_ver="v${t_ver}"
fi

if [ -z "${t_v2_ver}" ] || [ -z "${t_url}" ]; then
    echo "Fail to get the latest XTLS/Xray-core!"
    exit 1
fi

t_tarfile=${t_url##*/}

wget -q ${t_url}
unzip ${t_tarfile} -d ${t_xray_bin_dir}
rm -f ${t_tarfile}
chmod 0755 ${t_xray_bin_dir}/xray
ln -s ${t_xray_bin_dir}/xray ${t_xray_bin}
ln -s ${t_xray_bin_dir}/v2ctl ${t_v2ctl_bin}

cat << EOF | tee ${t_xray_conf}
{
    "log":{
        "loglevel":"debug"
    },
    "inbounds":[
        {
            "listen": "${t_xray_listen}",
            "port": ${t_xray_port},
            "allowPassive": false,
            "protocol": "vmess",
            "tag": "vmess-ws",
            "settings": {
                "clients": [
                    {
                        "id": "${t_uuid}",
                        "level": 0,
                        "alterId": 0
                    }
                ],
                "default": {
                    "level": 0,
                    "alterId": 0
                },
                "disableInsecureEncryption": true
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/${t_stream_ws_path}"
                }
            }
        }
    ],
    "outbounds":[
        {
            "protocol":"freedom"
        }
    ]
}
EOF

# http files
unzip ${t_demo_zip_file} -d ${t_www_dir} || exit 1
rm ${t_demo_zip_file}

# nginx
# delete default config
[ -f ${t_nginx_default_conf} ] && rm ${t_nginx_default_conf}
# remove run user settings
sed -i 's/^user[ ]*nginx;/#user nginx;/' ${t_nginx_conf}

# access control while share info generated
if [ ${t_gen_qr} -eq 1 ] && [ -n "${t_auth_user}" ] && [ -n "${t_auth_password}" ]; then
    htpasswd -cb ${t_nginx_httpasswd} ${t_auth_user} ${t_auth_password}
    # cat ${t_nginx_httpasswd}
    cat <<-EOF > ${t_nginx_www_conf}
server {
    listen         0.0.0.0:${t_http_port};
    listen         [::1]:${t_http_port};
    server_name    ${t_appname}.herokuapp.com 127.0.0.1 localhost;

    resolver 8.8.8.8 8.8.4.4 [2001:4860:4860::8888] [2001:4860:4860::8844];
    # Set HSTS to 365 days
    add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains; preload' always;
    fastcgi_hide_header X-Powered-By;
    location /${t_stream_ws_path} {
        proxy_set_header   Upgrade                  \$http_upgrade;
        proxy_set_header   Connection               "upgrade";
        proxy_set_header   Host                     \$http_host;
        proxy_set_header   X-Real-IP                \$remote_addr;
        proxy_set_header   X-Forwarded-For          \$proxy_add_x_forwarded_for;
        proxy_connect_timeout   360s;
        proxy_read_timeout      600s;
        proxy_send_timeout      600s;
        add_header         Front-End-Https on;
        proxy_pass         http://${t_xray_listen}:${t_xray_port}/${t_stream_ws_path};
        proxy_redirect     default;
    }
    root ${t_www_dir};
    index index.html index.htm;
    location /${t_share_qr_path} {
        autoindex on;
        auth_basic           "Administrator\'s Area";
        auth_basic_user_file ${t_nginx_httpasswd};
    }
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
else
    # no access control
    cat <<-EOF > ${t_nginx_www_conf}
server {
    listen         0.0.0.0:${t_http_port};
    listen         [::1]:${t_http_port};
    server_name    ${t_appname}.herokuapp.com 127.0.0.1 localhost;

    resolver 8.8.8.8 8.8.4.4 [2001:4860:4860::8888] [2001:4860:4860::8844];
    # Set HSTS to 365 days
    add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains; preload' always;
    fastcgi_hide_header X-Powered-By;
    location /${t_stream_ws_path} {
        proxy_set_header   Upgrade                  \$http_upgrade;
        proxy_set_header   Connection               "upgrade";
        proxy_set_header   Host                     \$http_host;
        proxy_set_header   X-Real-IP                \$remote_addr;
        proxy_set_header   X-Forwarded-For          \$proxy_add_x_forwarded_for;
        proxy_connect_timeout   360s;
        proxy_read_timeout      600s;
        proxy_send_timeout      600s;
        add_header         Front-End-Https on;
        proxy_pass         http://${t_xray_listen}:${t_xray_port}/${t_stream_ws_path};
        proxy_redirect     default;
    }
    root ${t_www_dir};
    index index.html index.htm;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
fi
# cat ${t_nginx_www_conf}

# generate share info
if [ ${t_gen_qr} -eq 0 ]; then
  echo "不生成二维码!"
else
    share_link=$(echo "vmess://${t_uuid}@${t_appname}.herokuapp.com:443?encryption=auto&security=tls&sni=${t_appname}.herokuapp.com&type=ws&host=${t_appname}.herokuapp.com&path=%2f${t_stream_ws_path}")
    echo -n "${share_link}" > ${t_share_file}
    echo -n "${share_link}" | qrencode -s 6 -o ${t_qr_file}
fi

# debug
# cat ${t_nginx_conf}
# cat ${t_nginx_www_conf}
# ls -al ${t_www_dir}
# ls -al ${t_www_dir}/${t_share_qr_path}

nginx -c ${t_nginx_conf} -p ${t_nginx_work_dir}
eval ${t_xray_bin} -config ${t_xray_conf}
