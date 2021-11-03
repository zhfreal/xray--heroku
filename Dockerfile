FROM alpine:latest

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates ca-certificates-bundle coreutils tar jq wget unzip libqrencode tzdata nginx curl apache2-utils uuidgen

ADD demo.zip /demo.zip
ADD entrypoint.sh /entrypoint.sh
CMD rm -rf /etc/localtime
CMD ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
CMD chmod +x /entrypoint.sh
CMD sh -x /entrypoint.sh
