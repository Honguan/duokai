#!/bin/bash

# 檢查是否以root使用者執行腳本
if [ "$(id -u)" != "0" ]; then
 echo "此腳本需要以root使用者權限執行。"
 echo "請嘗試使用 'sudo -i' 指令切換到root用戶，然後再次執行此腳本。"
 exit 1
fi

function install_node() {

# 讀取載入身分碼訊息
read -p "輸入你的身份碼: " id

# 讓使用者輸入想要建立的容器數量
read -p "請輸入你想要建立的節點數量，單IP限制最多5個節點: " container_count

# 讓使用者輸入起始 RPC 連接埠號
read -p "請輸入你想要設定的起始 RPC埠 （埠號請自行設定，開啟5個節點埠將會依序數字順延，建議輸入30000即可）: " start_rpc_port

# 讓使用者輸入想要分配的空間大小
read -p "請輸入你想要分配每個節點的儲存空間大小（GB），單一上限2T, 網頁生效較慢，等待20分鐘後，網頁查詢即可: " storage_gb

# 讓使用者輸入儲存路徑（選用）
read -p "請輸入節點儲存資料的宿主機路徑（直接回車將使用預設路徑 titan_storage_$i,依序數字順延）: " custom_storage_path

apt update

# 檢查 Docker 是否已安裝
if ! command -v docker &> /dev/null
then
 echo "未偵測到 Docker，正在安裝..."
 apt-get install ca-certificates curl gnupg lsb-release -y

 # 安裝 Docker 最新版本
 apt-get install docker.io -y
else
 echo "Docker 已安裝。"
fi

# 拉取Docker映像
docker pull nezha123/titan-edge:1.6_amd64

# 建立使用者指定數量的容器
for ((i=1; i<=container_count; i++))
do
 current_rpc_port=$((start_rpc_port + i - 1))

 # 判斷使用者是否輸入了自訂儲存路徑
 if [ -z "$custom_storage_path" ]; then
 # 使用者未輸入，使用預設路徑
 storage_path="$PWD/titan_storage_$i"
 else
 # 使用者輸入了自訂路徑，使用使用者提供的路徑
 storage_path="$custom_storage_path"
 fi

 # 確保儲存路徑存在
 mkdir -p "$storage_path"

 # 運行容器，並設定重新啟動策略為always
 container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan$i"  nezha123/titan-edge:1.6_amd64)

 echo "節點 titan$i 已經啟動 容器ID $container_id"

 sleep 30

 # 修改宿主機上的config.toml檔案以設定StorageGB值和連接埠
 docker exec $container_id bash -c "\
 sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
 sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_rpc_port\"/' /root/.titanedge/config. toml && \
 echo '容器 titan'$i' 的儲存空間設定為 $storage_gb GB，RPC 連接埠設定為 $current_rpc_port'"

 # 重新啟動容器以讓設定生效
 docker restart $container_id

 # 進入容器並執行綁定命令
 docker exec $container_id bash -c "\
 titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
 echo "節點 titan$i 已綁定."

done

echo "==============================所有節點均已設定並啟動=========== ========================"

}

# 卸載節點功能
function uninstall_node() {
 echo "你確定要卸載Titan 節點程式嗎？這將會刪除所有相關的資料。[Y/N]"
 read -r -p "請確認: " response

 case "$response" in
 [yY][eE][sS]|[yY])
 echo "開始卸載節點程式..."
 for i in {1..5}; do
 sudo docker stop "titan$i" && sudo docker rm "titan$i"
 done
 for i in {1..5}; do
 rmName="storage_titan_$i"
 rm -rf "$rmName"
 done
 echo "節點程式卸載完成。"
 ;;
 *)
 echo "取消卸載作業。"
 ;;
 esac
}


# 主選單
function main_menu() {
 while true; do
 clear
 echo "=================================================================="
 echo "退出腳本，請按鍵盤ctrl c退出即可"
 echo "請選擇要執行的動作:"
 echo "1. 安裝節點"
 echo "2. 卸載節點"
 read -p "請輸入選項（1-2）: " OPTION

 case $OPTION in
 1) install_node ;;
 2) uninstall_node ;;
 *) echo "無效選項。" ;;
 esac
 echo "按任意鍵返回主選單..."
 read -n 1
 done

}

# 顯示主選單
main_menu
