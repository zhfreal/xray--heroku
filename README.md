### 部署
一键部署 github.com/XTLS/Xray-core 到 heroku  
[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

#### 1.部署时配置:
  > "APPNAME": 请输入最上方填写的App Name；

  > "VER": 默认"latest", 安装最新版本Xray-core; 输入Xray-core版本号进行指定版本安装。例如：1.5.0; 默认"latest"；

  > "UUID": Vmess协议默认UUID，请输入自己的UUID；

  > "WS_PATH": Path路径，默认"/myapp"；

  > "GENQR": 是否生成QR图片，"Yes|YES|yes|no|NO|No|1|0"。默认"no"，即不生成分享；

  > "SHARE_QR_PATH": 二维码和订阅地址路径。如GENQR变量为"no"，此变量没有作用；

  > "AUTH_USER": 分享访问的用户名，用于控制分享显示。如GENQR变量为"no"，此变量没有作用；

  > "AUTH_PASSWORD": 分享访问的密码，用于控制分享显示。如GENQR变量为"no"，此变量没有作用。
#### 2.验证部署
服务端部署后，点 open app ，能正常显示网页; 地址补上"SHARE_QR_PATH"后访问, 显示"Bad Request"，表示部署成功.
#### 3.分享地址
- 如果部署时选择生成二维码信息，则自动生成订阅地址和二维码，通过配置 "SHARE_QR_PATH" 变量修改地址；

- 二维码地址：
  > https://[AUTH_USER]:[AUTH_PASSWORD]@[APPNAME].herokuapp.com/[SHARE_QR_PATH]/xray.png
- 订阅地址：
  > https://[AUTH_USER]:[AUTH_PASSWORD]@[APPNAME].herokuapp.com/[SHARE_QR_PATH]/index.html

注意：订阅地址和二维码的访问可通过用户名和密码实现访问控制，避免自己的信息泄露！
#### 4. 更新版本
- 访问 "https://dashboard.heroku.com/apps" , 选择部署好xray-core的app； 
- 如果VER变量为 "latest"， 直接选择 "More --> Restart all dynos"；
- 更新指定版本： 
  - "Settings --> Reveal Config Varsapp -->VER"，修改成需要的版本号，例如 1.5.0）
  - 选择 "More --> Restart all dynos"；
- 通过"More --> View logs"确认进度。


### 参考 
https://github.com/XTLS/Xray-core

https://github.com/wangyi2005/v2ray-heroku

https://github.com/1715173329/v2ray-heroku-undone
