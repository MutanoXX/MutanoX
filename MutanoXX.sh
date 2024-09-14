#!/data/data/com.termux/files/usr/bin/sh

# Informações do criador e do módulo
CREATOR_NAME="MutanoX"
CHANNEL_NAME="Mutanomodsoficial"
MODULE_VERSION="1.0.9"
CREATION_DATE="2024-01-01"
DEVELOPER_NAME="MutanoX Dev Team"

# Configurações padrão
DEFAULT_SENSITIVITY=10
MAX_SENSITIVITY=30
EXTREME_SENSITIVITY=20
NEAR_DISTANCE_THRESHOLD=10
HEAD_HEIGHT_LIMIT=130.0  # Limite superior para a mira (altura da cabeça)
NECK_HEIGHT_LIMIT=115.0   # Limite superior para a mira (altura do pescoço)

# Arquivo de log e configuração
LOG_FILE="mutanox_script.log"
CONFIG_FILE="mutanox_config.conf"

# Variáveis de desempenho
successful_hits=0
total_shots=0

# Funções utilitárias
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

initialize_log_file() {
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        log_message "Arquivo de log criado."
    fi
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "Configurações carregadas."
    else
        log_message "Arquivo de configuração não encontrado. Usando configurações padrão."
    fi
}

save_config() {
    cat <<EOL > "$CONFIG_FILE"
DEFAULT_SENSITIVITY=$DEFAULT_SENSITIVITY
MAX_SENSITIVITY=$MAX_SENSITIVITY
EOL
    log_message "Configurações salvas."
}

print_separator() {
    echo "==========================================="
}

print_title() {
    echo -e "\033[1;32m########## $1 ##########\033[0m"
}

print_large_title() {
    echo -e "\033[1;34m"
    echo "  _____ _           _   _                 "
    echo " |_   _| |         | | (_)                "
    echo "   | | | |__   __ _| |_ _  __ _ _ __ ___  "
    echo "   | | | '_ \\ / _\` | __| |/ _\` | '_ \` _ \\ "
    echo "  _| |_| | | | (_| | |_| | (_| | | | | | |"
    echo " |_____|_| |_|\\__,_|\\__|_|\\__,_|_| |_| |_|"
    echo "          By MutanoX          "
    echo -e "\033[0m"
}

print_panel() {
    echo -e "\033[1;36m"
    echo "  ****************************************  "
    echo "  *          M  U  T  A  N  O  X         *  "
    echo "  ****************************************  "
    echo "  *    Pressione 1 para Iniciar o Script   *  "
    echo "  *       Pressione 0 para Sair            *  "
    echo "  ****************************************  "
    echo -e "\033[0m"
}

log_device_information() {
    echo "📱 Dispositivo: $(getprop ro.product.brand) $(getprop ro.product.model)"
    echo "💻 ID do Dispositivo: $(getprop ro.serialno)"
    echo "📅 Versão do Sistema: $(getprop ro.build.version.release)"
    echo "🏭 Fabricante: $(getprop ro.product.manufacturer)"
    echo "🔋 Estado da Bateria: $(dumpsys battery | grep level | awk '{print $2}')%"
}

calculate_aim() {
    local player_x=100.0 player_y=200.0
    local head_x=150.0 head_y=145.0

    # Calcular deltas e distância
    local delta_x=$(echo "$head_x - $player_x" | bc)
    local delta_y=$(echo "$head_y - $player_y" | bc)
    local distance=$(echo "scale=2; sqrt($delta_x^2 + $delta_y^2)" | bc)
    distance=$(echo "${distance:-0.01}")

    # Ajustar a altura da mira para o pescoço ou cabeça
    if (( $(echo "$head_y > $HEAD_HEIGHT_LIMIT" | bc -l) )); then
        head_y=$HEAD_HEIGHT_LIMIT  # Mira na cabeça
    elif (( $(echo "$head_y > $NECK_HEIGHT_LIMIT" | bc -l) )); then
        head_y=$NECK_HEIGHT_LIMIT   # Mira no pescoço
    fi

    # Recalcular delta_y com a nova altura
    delta_y=$(echo "$head_y - $player_y" | bc)

    # Calcular ângulo
    local angle_x=$(echo "scale=10; a($delta_y/$delta_x)*180/4*a(1)" | bc -l)
    angle_x=$(adjust_angle "$delta_x" "$angle_x")

    # Calcular multiplicador de sensibilidade
    local sensitivity_multiplier=$(calculate_sensitivity_multiplier "$distance")

    # Calcular sensibilidade base
    local base_sensitivity=$(echo "scale=2; 10 / $distance * $DEFAULT_SENSITIVITY" | bc)
    base_sensitivity=$(echo "${base_sensitivity:-0}")

    # Ajustar ângulo e sensibilidade
    local angle_adjustment=$(echo "scale=2; $base_sensitivity * (1 - ($angle_x / 90)) * $sensitivity_multiplier" | bc)

    if [ "$is_one_shot_gun_mode" = true ]; then
        angle_adjustment=$(echo "$angle_adjustment < $HEADSHOT_THRESHOLD ? $angle_adjustment : $HEADSHOT_THRESHOLD" | bc)
    fi

    local final_sensitivity=$(echo "$base_sensitivity + $angle_adjustment" | bc)
    final_sensitivity=$(echo "$final_sensitivity > $MAX_SENSITIVITY ? $MAX_SENSITIVITY : $final_sensitivity" | bc)

    apply_sensitivity "$final_sensitivity"
}

adjust_angle() {
    local delta_x="$1"
    local angle_x="$2"

    if [ "$(echo "$delta_x < 0" | bc)" -eq 1 ]; then
        angle_x=$(echo "if($angle_x > 0) 180 + $angle_x; else if($angle_x < -90) -90; else $angle_x" | bc)
    else
        angle_x=$(echo "if($angle_x < 0) 360 + $angle_x; else if($angle_x > 90) 90; else $angle_x" | bc)
    fi

    echo "$angle_x"
}

calculate_sensitivity_multiplier() {
    local distance="$1"
    local multiplier=1

    # Ajuste da sensibilidade baseado na distância
    if [ "$distance" -le 10 ]; then
        multiplier=2.0  # Aumentar sensibilidade para combates próximos
    elif [ "$distance" -le 25 ]; then
        multiplier=1.5  # Sensibilidade padrão para distâncias médias
    else
        multiplier=1.0  # Reduzir a sensibilidade para distâncias longas
    fi

    echo "$multiplier"
}

adjust_sensitivity_based_on_performance() {
    if [ $total_shots -gt 0 ]; then
        local hit_ratio=$(echo "scale=2; $successful_hits / $total_shots" | bc)

        if (( $(echo "$hit_ratio > 0.7" | bc -l) )); then
            # Se a taxa de acertos for alta, aumentar a sensibilidade
            DEFAULT_SENSITIVITY=$(echo "$DEFAULT_SENSITIVITY + 1" | bc)
        elif (( $(echo "$hit_ratio < 0.3" | bc -l) )); then
            # Se a taxa de acertos for baixa, diminuir a sensibilidade
            DEFAULT_SENSITIVITY=$(echo "$DEFAULT_SENSITIVITY - 1" | bc)
        fi

        # Garantir que a sensibilidade esteja dentro dos limites
        if [ "$DEFAULT_SENSITIVITY" -gt "$MAX_SENSITIVITY" ]; then
            DEFAULT_SENSITIVITY="$MAX_SENSITIVITY"
        elif [ "$DEFAULT_SENSITIVITY" -lt 0 ]; then
            DEFAULT_SENSITIVITY=0
        fi

        echo "🔄 Sensibilidade ajustada para: $DEFAULT_SENSITIVITY (Taxa de acertos: $hit_ratio)"
        log_message "Sensibilidade ajustada para: $DEFAULT_SENSITIVITY (Taxa de acertos: $hit_ratio)"
    fi
}

apply_sensitivity() {
    local final_sensitivity="$1"

    if [ -n "$final_sensitivity" ] && [ "$(echo "$final_sensitivity >= 0" | bc)" -eq 1 ]; then
        settings put system pointer_speed "$final_sensitivity"
        echo "✔ Sensibilidade ajustada para: $final_sensitivity"
        log_message "Sensibilidade ajustada para: $final_sensitivity"
    else
        echo "❌ Sensibilidade inválida: $final_sensitivity"
        log_message "Tentativa de ajustar sensibilidade inválida: $final_sensitivity"
    fi
}

adjust_touch_sensitivity() {
    print_separator
    print_title "Ajustando Sensibilidade"
    apply_sensitivity "$EXTREME_SENSITIVITY"
}

detect_closest_target() {
    print_separator
    print_title "Detectando Alvo"
    echo "🔍 Detectando alvo mais próximo..."
    calculate_aim
}

countdown() {
    print_separator
    print_title "Contagem Regressiva"
    echo "⏳ Contagem regressiva para abrir Free Fire:"
    for i in $(seq 5 -1 1); do 
        echo "$i..."
        sleep 1
    done
    echo "🚀 Preparado para o combate!"
}

initialize_game() {
    print_separator
    print_large_title
    log_device_information
    adjust_touch_sensitivity
    detect_closest_target
    countdown
    print_separator
    echo "🚀 Abrindo Free Fire..."
    am start -n com.dts.freefireth/.FFMainActivity
    log_message "Iniciando o jogo Free Fire."
}

# Configuração do usuário
configure_settings() {
    echo "Configurações atuais:"
    echo "Sensibilidade padrão: $DEFAULT_SENSITIVITY"
    echo "Sensibilidade máxima: $MAX_SENSITIVITY"
    
    read -p "Deseja ajustar a sensibilidade padrão? (s/n): " adjust_sensitivity
    if [[ "$adjust_sensitivity" =~ ^[sS]$ ]]; then
        read -p "Digite a nova sensibilidade padrão (0-$MAX_SENSITIVITY): " new_sensitivity
        if [[ "$new_sensitivity" =~ ^[0-9]+$ ]] && [ "$new_sensitivity" -ge 0 ] && [ "$new_sensitivity" -le "$MAX_SENSITIVITY" ]; then
            DEFAULT_SENSITIVITY="$new_sensitivity"
            echo "Sensibilidade padrão ajustada para: $DEFAULT_SENSITIVITY"
            log_message "Sensibilidade padrão ajustada para: $DEFAULT_SENSITIVITY"
            save_config
        else
            echo "❌ Valor inválido. Mantendo a sensibilidade padrão: $DEFAULT_SENSITIVITY"
        fi
    fi
}

# Função de autoajuste em loop
auto_adjust() {
    while true; do
        # Simulando a distância do alvo
        local target_distance=$(echo "$(( RANDOM % 50 + 1 ))")  # Distância aleatória entre 1 e 50
        echo "🔍 Distância do alvo: $target_distance"

        # Ajustar a sensibilidade com base na distância
        local adjusted_sensitivity=$(calculate_sensitivity_multiplier "$target_distance")
        apply_sensitivity "$adjusted_sensitivity"

        # Simulação de acertos e tiros
        total_shots=$((total_shots + 1))
        if [ $(( RANDOM % 10 )) -lt 3 ]; then  # 30% de chance de acerto
            successful_hits=$((successful_hits + 1))
            echo "✔ Acerto! Total de acertos: $successful_hits"
        else
            echo "❌ Erro! Total de acertos: $successful_hits"
        fi

        # Ajustar a sensibilidade com base na performance
        adjust_sensitivity_based_on_performance

        sleep 5  # Ajustar a cada 5 segundos
    done
}

# Função para verificar requisitos do sistema
check_system_requirements() {
    echo "🔍 Verificando requisitos do sistema..."
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ Este script precisa ser executado como root."
        log_message "Tentativa de execução sem privilégios de root."
        exit 1
    fi
    echo "✔ Requisitos do sistema atendidos."
}

# Função principal para iniciar o script
main() {
    initialize_log_file
    load_config
    check_system_requirements
    print_panel
    read -p "Pressione 1 para iniciar o script ou 0 para sair: " user_input

    if [[ "$user_input" =~ ^[1]$ ]]; then
        configure_settings
        # Simulação se a arma atual é AR ou SMG
        is_ar_sm_mode=false  # Altere para 'true' se estiver em modo AR/SMG
        is_one_shot_gun_mode=true  # Altere para 'true' se estiver usando uma arma de um tiro

        # Iniciar o script
        initialize_game
        
        # Iniciar o autoajuste em segundo plano
        auto_adjust &
    else
        echo "❌ Saindo do script."
        log_message "Script encerrado pelo usuário."
        exit 0
    fi
}

# Executar a função principal
main
