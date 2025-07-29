#!/bin/bash

### WINE GAMING SETUP SCRIPT - OPTIMIZED ###
### Configuração otimizada para jogos no Linux com suporte Intel ###

set -e  # Para em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para logs coloridos
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_gpu() { echo -e "${PURPLE}🎮 $1${NC}"; }
log_intel() { echo -e "${CYAN}🔷 Intel: $1${NC}"; }

### CONFIGURAÇÕES ###
PREFIX="${1:-$HOME/Games/wine-gaming}"
ARCH="win64"
DXVK_VERSION="2.3.1"
VKD3D_VERSION="2.12"
WINE_GECKO_VERSION="2.47.4"
WINE_MONO_VERSION="8.1.0"

# URLs
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v$DXVK_VERSION/dxvk-$DXVK_VERSION.tar.gz"
VKD3D_URL="https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v$VKD3D_VERSION/vkd3d-proton-$VKD3D_VERSION.tar.xz"

# Variáveis globais para detecção de hardware
GPU_VENDOR=""
GPU_MODEL=""
CPU_CORES=""
AVAILABLE_RAM=""
KERNEL_VERSION=""
MESA_VERSION=""
IS_WAYLAND=""

log_info "🍷 Iniciando configuração do ambiente Wine Gaming Optimized"
log_info "📁 Prefixo: $PREFIX"
log_info "🏗️  Arquitetura: $ARCH"

# Detectar sistema e hardware
detect_system() {
    log_info "🔍 Detectando sistema e hardware..."
    
    # Detectar Kernel
    KERNEL_VERSION=$(uname -r)
    log_info "🐧 Kernel: $KERNEL_VERSION"
    
    # Verificar se Mesa está disponível e versão
    if command -v glxinfo &> /dev/null; then
        MESA_VERSION=$(glxinfo | grep "OpenGL version" | cut -d' ' -f4 | head -1)
        log_info "🎨 Mesa/OpenGL: $MESA_VERSION"
    fi
    
    # Detectar se está no Wayland
    if [ "$XDG_SESSION_TYPE" = "wayland" ] || [ "$WAYLAND_DISPLAY" ]; then
        IS_WAYLAND="true"
        log_info "🖥️  Protocolo: Wayland detectado"
    else
        IS_WAYLAND="false"
        log_info "🖥️  Protocolo: X11"
    fi
    
    # Detectar GPU
    if lspci | grep -i "vga\|3d\|display" | grep -qi intel; then
        GPU_VENDOR="intel"
        GPU_MODEL=$(lspci | grep -i "vga\|3d\|display" | grep -i intel | head -1 | cut -d: -f3 | sed 's/^ *//')
        log_intel "GPU Intel detectada: $GPU_MODEL"
    elif lspci | grep -i "vga\|3d\|display" | grep -qi nvidia; then
        GPU_VENDOR="nvidia"
        GPU_MODEL=$(lspci | grep -i "vga\|3d\|display" | grep -i nvidia | head -1 | cut -d: -f3 | sed 's/^ *//')
        log_gpu "GPU NVIDIA detectada: $GPU_MODEL"
    elif lspci | grep -i "vga\|3d\|display" | grep -qi amd; then
        GPU_VENDOR="amd"
        GPU_MODEL=$(lspci | grep -i "vga\|3d\|display" | grep -i amd | head -1 | cut -d: -f3 | sed 's/^ *//')
        log_gpu "GPU AMD detectada: $GPU_MODEL"
    else
        GPU_VENDOR="unknown"
        log_warning "GPU não identificada"
    fi
    
    # Detectar CPU
    CPU_CORES=$(nproc)
    log_info "🖥️  CPU cores: $CPU_CORES"
    
    # Detectar RAM
    AVAILABLE_RAM=$(free -m | awk 'NR==2{printf "%.0f", $7*0.8 }')
    log_info "🧠 RAM disponível: ${AVAILABLE_RAM}MB"
    
    # Verificar se é Intel integrado
    if [[ "$GPU_VENDOR" == "intel" ]]; then
        log_intel "Aplicando otimizações específicas para Intel Graphics"
        check_intel_requirements
    fi
    
    # Verificar Vulkan por vendor
    check_vulkan_support
}

# Verificar suporte Vulkan específico por vendor
check_vulkan_support() {
    log_info "🌋 Verificando suporte Vulkan..."
    
    if command -v vulkaninfo &> /dev/null; then
        case "$GPU_VENDOR" in
            "intel")
                if vulkaninfo 2>/dev/null | grep -qi "intel.*vulkan\|ANV"; then
                    log_intel "Vulkan Intel (ANV) disponível"
                else
                    log_warning "Vulkan Intel pode não estar funcionando"
                fi
                ;;
            "nvidia")
                if vulkaninfo 2>/dev/null | grep -qi "nvidia"; then
                    log_gpu "Vulkan NVIDIA disponível"
                else
                    log_warning "Vulkan NVIDIA pode não estar funcionando"
                fi
                ;;
            "amd")
                if vulkaninfo 2>/dev/null | grep -qi "amd\|radv"; then
                    log_gpu "Vulkan AMD (RADV) disponível"
                else
                    log_warning "Vulkan AMD pode não estar funcionando"
                fi
                ;;
        esac
    else
        log_warning "vulkaninfo não encontrado"
    fi
}

# Verificar requisitos específicos para Intel
check_intel_requirements() {
    log_intel "Verificando drivers Intel..."
    
    # Verificar se mesa está instalado
    if ! dpkg -l 2>/dev/null | grep -q "mesa-vulkan-drivers\|intel-media-va-driver" && \
       ! pacman -Q 2>/dev/null | grep -q "mesa\|vulkan-intel"; then
        log_warning "Drivers Intel podem não estar otimizados"
        log_info "Para Ubuntu/Debian: sudo apt install mesa-vulkan-drivers intel-media-va-driver i965-va-driver"
        log_info "Para Arch: sudo pacman -S mesa vulkan-intel intel-media-driver"
        log_info "Para Fedora: sudo dnf install mesa-vulkan-drivers intel-media-driver"
    else
        log_success "Drivers Intel detectados"
    fi
}

# Verificar dependências com suporte Flatpak
check_dependencies() {
    log_info "🔍 Verificando dependências..."
    
    local deps=("wine" "winetricks" "wget" "tar" "lspci")
    local wine_found=false
    local winetricks_found=false
    
    # Verificar Wine padrão
    if command -v wine &> /dev/null; then
        wine_found=true
        log_success "Wine nativo encontrado: $(wine --version)"
    fi
    
    # Verificar Flatpak Wine
    if command -v flatpak &> /dev/null; then
        if flatpak list | grep -q "org.winehq.Wine"; then
            wine_found=true
            log_success "Wine Flatpak encontrado"
            # Criar alias para usar Wine do Flatpak
            cat > /tmp/wine_flatpak_setup.sh << 'EOF'
#!/bin/bash
alias wine='flatpak run org.winehq.Wine'
alias winecfg='flatpak run org.winehq.Wine winecfg'
alias wineserver='flatpak run org.winehq.Wine wineserver'
EOF
            source /tmp/wine_flatpak_setup.sh
        fi
        
        # Verificar protontricks como alternativa ao winetricks
        if flatpak list | grep -q "com.github.Matoking.protontricks"; then
            winetricks_found=true
            log_success "Protontricks Flatpak encontrado"
        fi
    fi
    
    # Verificar winetricks padrão
    if command -v winetricks &> /dev/null; then
        winetricks_found=true
        log_success "Winetricks nativo encontrado"
    fi
    
    # Verificar outras dependências
    for dep in "wget" "tar" "lspci"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Dependência não encontrada: $dep"
            log_info "Para Ubuntu/Debian: sudo apt install wget tar pciutils"
            log_info "Para Arch: sudo pacman -S wget tar pciutils"
            log_info "Para Fedora: sudo dnf install wget tar pciutils"
            exit 1
        fi
    done
    
    if ! $wine_found; then
        log_error "Wine não encontrado!"
        log_info "Instale Wine ou use: flatpak install flathub org.winehq.Wine"
        exit 1
    fi
    
    if ! $winetricks_found; then
        log_warning "Winetricks não encontrado. Algumas funcionalidades podem não funcionar."
    fi
    
    log_success "Dependências verificadas"
}

# Criar e configurar prefixo
setup_prefix() {
    log_info "📁 Criando prefixo WINEPREFIX em $PREFIX"
    
    # Backup se já existir
    if [ -d "$PREFIX" ]; then
        log_warning "Prefixo já existe. Criando backup..."
        mv "$PREFIX" "${PREFIX}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$PREFIX"
    export WINEPREFIX="$PREFIX"
    export WINEARCH="$ARCH"
    
    # Configurações específicas para Wayland
    if [[ "$IS_WAYLAND" == "true" ]]; then
        log_info "🖥️  Configurando para Wayland..."
        export WINE_VK_USE_FSR=1
        export DXVK_FILTER_DEVICE_NAME=""
    fi
    
    log_info "🚀 Inicializando Wine..."
    wineboot -u
    
    log_success "Prefixo criado com sucesso"
}

# Configurar Wine com otimizações específicas
configure_wine() {
    log_info "⚙️  Configurando Wine..."
    
    # Configurações base do registro
    cat > /tmp/wine_gaming.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Wine\DirectSound]
"DefaultBitsPerSample"=dword:00000010
"DefaultSampleRate"=dword:0000ac44

[HKEY_CURRENT_USER\Software\Wine\DirectInput]
"MouseWarpOverride"="force"

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"GrabPointer"="Y"
"UseTakeFocus"="N"
"Decorated"="Y"
"ScreenDepth"=dword:00000020
EOF
    
    # Configurações específicas para Wayland
    if [[ "$IS_WAYLAND" == "true" ]]; then
        log_info "🖥️  Aplicando configurações para Wayland..."
        cat >> /tmp/wine_gaming.reg << 'EOF'

[HKEY_CURRENT_USER\Software\Wine\Wayland Driver]
"DecorationMode"=dword:00000001
"ProcessEvents"="Y"
EOF
    fi
    
    # Configurações específicas para Intel
    if [[ "$GPU_VENDOR" == "intel" ]]; then
        log_intel "Aplicando configurações específicas para Intel Graphics..."
        cat >> /tmp/wine_gaming.reg << 'EOF'

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"VideoPciDeviceID"=dword:00000000
"VideoPciVendorID"=dword:00008086
"VideoMemorySize"=dword:40000000
"UseGLSL"="enabled"
"OffScreenRenderingMode"="fbo"
"RenderTargetLockMode"="disabled"
"Multisampling"="enabled"
"AlwaysOffscreen"="disabled"
"StrictDrawOrdering"="disabled"
EOF
    fi
    
    WINEPREFIX="$PREFIX" wine regedit /tmp/wine_gaming.reg
    rm /tmp/wine_gaming.reg
    
    log_success "Wine configurado"
}

# Instalar bibliotecas com Winetricks
install_libraries() {
    if ! command -v winetricks &> /dev/null; then
        log_warning "Winetricks não disponível, pulando instalação de bibliotecas"
        return 0
    fi
    
    log_info "📦 Instalando bibliotecas essenciais com Winetricks..."
    
    # Bibliotecas básicas
    local basic_libs=(
        "corefonts"
        "vcrun2019"
        "vcrun2022"
        "dotnet48"
        "d3dx9"
        "d3dx10"
        "d3dx11"
        "d3dcompiler_43"
        "d3dcompiler_47"
        "xact"
        "xinput"
    )
    
    # Bibliotecas adicionais para Intel
    if [[ "$GPU_VENDOR" == "intel" ]]; then
        log_intel "Adicionando bibliotecas específicas para Intel..."
        basic_libs+=(
            "physx"
            "openal"
            "dsound"
        )
    fi
    
    log_info "🔧 Instalando bibliotecas..."
    WINEPREFIX="$PREFIX" winetricks -q "${basic_libs[@]}"
    
    log_success "Bibliotecas instaladas"
}

# Instalar DXVK com configurações específicas
install_dxvk() {
    log_info "🌐 Baixando e instalando DXVK $DXVK_VERSION"
    
    cd /tmp
    if [ ! -f "dxvk-$DXVK_VERSION.tar.gz" ]; then
        wget --progress=bar:force "$DXVK_URL"
    fi
    
    tar -xzf "dxvk-$DXVK_VERSION.tar.gz"
    cd "dxvk-$DXVK_VERSION"
    
    WINEPREFIX="$PREFIX" ./setup_dxvk.sh install
    
    # Configuração específica para Intel
    if [[ "$GPU_VENDOR" == "intel" ]]; then
        log_intel "Configurando DXVK para Intel Graphics..."
        cat > "$PREFIX/dxvk.conf" << EOF
# Configuração DXVK para Intel Graphics
dxgi.maxFrameLatency = 1
d3d11.samplerAnisotropy = 4
d3d9.samplerAnisotropy = 4
d3d11.invariantPosition = True
d3d11.floatControls = Strict
dxvk.enableAsync = True
dxvk.numCompilerThreads = $((CPU_CORES >= 4 ? CPU_CORES / 2 : 2))
EOF
    fi
    
    log_success "DXVK $DXVK_VERSION instalado"
}

# Instalar VKD3D-Proton (com verificação Intel)
install_vkd3d() {
    if [[ "$GPU_VENDOR" == "intel" ]]; then
        log_intel "Verificando compatibilidade VKD3D com Intel..."
        if ! vulkaninfo 2>/dev/null | grep -qi "intel\|ANV"; then
            log_warning "VKD3D pode não funcionar bem com sua Intel Graphics. Pulando..."
            return 0
        fi
    fi
    
    log_info "🚀 Baixando e instalando VKD3D-Proton $VKD3D_VERSION"
    
    cd /tmp
    if [ ! -f "vkd3d-proton-$VKD3D_VERSION.tar.xz" ]; then
        wget --progress=bar:force "$VKD3D_URL"
    fi
    
    tar -xJf "vkd3d-proton-$VKD3D_VERSION.tar.xz"
    cd "vkd3d-proton-$VKD3D_VERSION"
    
    WINEPREFIX="$PREFIX" ./setup_vkd3d_proton.sh install
    
    log_success "VKD3D-Proton $VKD3D_VERSION instalado"
}

# Configurações de performance específicas por GPU
optimize_performance() {
    log_info "🚀 Aplicando otimizações de performance..."
    
    # Configurações base
    cat > "$PREFIX/wine_gaming_env.sh" << EOF
#!/bin/bash
# Variáveis de ambiente para Wine Gaming

# Wine
export WINEPREFIX="$PREFIX"
export WINEDEBUG=-all
export WINE_CPU_TOPOLOGY=$((CPU_CORES >= 8 ? CPU_CORES/2 : CPU_CORES)):$((CPU_CORES >= 4 ? 2 : 1))

# DXVK base
export DXVK_STATE_CACHE=1
export DXVK_LOG_LEVEL=warn

# VKD3D
export VKD3D_CONFIG=dxr
export VKD3D_SHADER_MODEL=6_6

# Performance geral
export __GL_THREADED_OPTIMIZATIONS=1
export __GL_SHADER_DISK_CACHE=1
export mesa_glthread=true

# Networking
export WINE_RT_POLICY=2
EOF

    # Configurações específicas para Wayland
    if [[ "$IS_WAYLAND" == "true" ]]; then
        cat >> "$PREFIX/wine_gaming_env.sh" << EOF

# === CONFIGURAÇÕES WAYLAND ===
export WINE_VK_USE_FSR=1
export SDL_VIDEODRIVER=wayland
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
EOF
    fi

    # Otimizações específicas por GPU
    case "$GPU_VENDOR" in
        "intel")
            log_intel "Aplicando otimizações para Intel Graphics..."
            cat >> "$PREFIX/wine_gaming_env.sh" << EOF

# === OTIMIZAÇÕES INTEL GRAPHICS ===
export DXVK_HUD=fps,memory
export INTEL_DEBUG=
export ANV_SAMPLE_MASK_OUT_OPENGL_BEHAVIOUR=true
export MESA_LOADER_DRIVER_OVERRIDE=i965
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLSL_VERSION_OVERRIDE=460

# Intel específico - reduzir uso de VRAM
export DXVK_CONFIG_FILE="\$WINEPREFIX/dxvk.conf"
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json

# Otimizações de memória para Intel integrado
export WINEDLLOVERRIDES="d3d11=n;dxgi=n"
export WINE_HEAP_DELAY_FREE=1

echo "🔷 Ambiente otimizado para Intel Graphics carregado!"
EOF
            ;;
        "nvidia")
            cat >> "$PREFIX/wine_gaming_env.sh" << EOF

# === OTIMIZAÇÕES NVIDIA ===
export DXVK_HUD=fps,memory,gpuload
export __GL_SYNC_TO_VBLANK=0
export __GL_VRR_ALLOWED=1
export NVIDIA_THREADED_OPTIMIZATIONS=1

echo "💚 Ambiente otimizado para NVIDIA carregado!"
EOF
            ;;
        "amd")
            cat >> "$PREFIX/wine_gaming_env.sh" << EOF

# === OTIMIZAÇÕES AMD ===
export DXVK_HUD=fps,memory,gpuload
export RADV_PERFTEST=gpl,sam
export ACO_DEBUG=validateir,validatera
export MESA_VK_VERSION_OVERRIDE=1.3

echo "❤️ Ambiente otimizado para AMD carregado!"
EOF
            ;;
        *)
            cat >> "$PREFIX/wine_gaming_env.sh" << EOF

# === CONFIGURAÇÕES GENÉRICAS ===
export DXVK_HUD=fps,memory

echo "🎮 Ambiente genérico carregado!"
EOF
            ;;
    esac
    
    cat >> "$PREFIX/wine_gaming_env.sh" << EOF

echo "📁 Prefixo: \$WINEPREFIX"
echo "🖥️  GPU: $GPU_VENDOR - $GPU_MODEL"
echo "🧠 Usando ${AVAILABLE_RAM}MB de RAM disponível"
echo "🐧 Kernel: $KERNEL_VERSION"
echo "🖥️  Protocolo: $([ "$IS_WAYLAND" == "true" ] && echo "Wayland" || echo "X11")"
EOF
    
    chmod +x "$PREFIX/wine_gaming_env.sh"
    
    log_success "Otimizações aplicadas para $GPU_VENDOR"
}

# Criar scripts utilitários otimizados
create_utilities() {
    log_info "🛠️  Criando scripts utilitários..."
    
    # Script de configuração
    cat > "$PREFIX/configure.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/wine_gaming_env.sh"
winecfg
EOF
    
    # Script para instalar mais programas
    cat > "$PREFIX/install_more.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/wine_gaming_env.sh"
if command -v winetricks &> /dev/null; then
    winetricks
else
    echo "❌ Winetricks não encontrado"
    echo "Para instalar: sudo apt install winetricks (Ubuntu/Debian)"
    echo "               sudo pacman -S winetricks (Arch)"
    echo "               flatpak install flathub com.github.Matoking.protontricks"
fi
EOF
    
    # Script de limpeza avançada
    cat > "$PREFIX/cleanup.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/wine_gaming_env.sh"

echo "🧹 Limpando cache e arquivos temporários..."
rm -rf "$WINEPREFIX/drive_c/users/$USER/Temp/*" 2>/dev/null
rm -rf "$WINEPREFIX/drive_c/windows/Temp/*" 2>/dev/null
find "$WINEPREFIX" -name "*.log" -delete 2>/dev/null
find "$WINEPREFIX" -name "*.tmp" -delete 2>/dev/null

# Limpar cache DXVK
if [ -d "$HOME/.cache/dxvk-cache" ]; then
    echo "🗑️  Limpando cache DXVK..."
    rm -rf "$HOME/.cache/dxvk-cache/*"
fi

# Limpar cache Mesa
if [ -d "$HOME/.cache/mesa_shader_cache" ]; then
    echo "🗑️  Limpando cache Mesa..."
    rm -rf "$HOME/.cache/mesa_shader_cache/*"
fi

# Compactar registro do Wine
echo "📝 Compactando registro do Wine..."
wineserver -k
wine regedit /E /tmp/wine_backup.reg 2>/dev/null
if [ -f "/tmp/wine_backup.reg" ]; then
    wine regedit /D HKEY_CURRENT_USER 2>/dev/null
    wine regedit /tmp/wine_backup.reg 2>/dev/null
    rm /tmp/wine_backup.reg
fi

echo "✅ Limpeza concluída"
EOF
    
    # Script simples para executar executáveis
    cat > "$PREFIX/wine_run.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/wine_gaming_env.sh"

if [ -z "$1" ]; then
    echo "Uso: $0 <arquivo.exe>"
    exit 1
fi

echo "🎮 Executando: $1"
cd "$(dirname "$1")" 2>/dev/null || true
wine "$1"
EOF
    
    chmod +x "$PREFIX"/*.sh
    
    log_success "Scripts utilitários criados"
}

# Teste final com informações detalhadas
final_test() {
    log_info "🧪 Testando instalação..."
    
    source "$PREFIX/wine_gaming_env.sh"
    
    # Testar Wine
    if WINEPREFIX="$PREFIX" wine --version &> /dev/null; then
        log_success "Wine funcionando corretamente: $(wine --version)"
    else
        log_error "Problema com Wine"
        return 1
    fi
    
    # Testar DXVK
    if ls "$PREFIX/drive_c/windows/system32/dxgi.dll" &> /dev/null; then
        log_success "DXVK instalado corretamente"
    else
        log_warning "DXVK pode não estar instalado corretamente"
    fi
    
    # Testes específicos para Intel
    if [[ "$GPU_VENDOR" == "intel" ]]; then
        log_intel "Executando testes específicos para Intel..."
        
        if [ -f "$PREFIX/dxvk.conf" ]; then
            log_intel "Configuração DXVK Intel encontrada"
        fi
        
        if command -v vainfo &> /dev/null; then
            if vainfo 2>/dev/null | grep -qi intel; then
                log_intel "Aceleração de vídeo Intel funcionando"
            fi
        fi
    fi
    
    log_success "Instalação concluída!"
}

# Exibir instruções finais otimizadas
show_instructions() {
    log_info "📋 Instruções de uso:"
    echo
    echo "=== CONFIGURAÇÃO ATUAL ==="
    echo "GPU: $GPU_VENDOR - $GPU_MODEL"
    echo "CPU Cores: $CPU_CORES"
    echo "RAM Disponível: ${AVAILABLE_RAM}MB"
    echo "Kernel: $KERNEL_VERSION"
    echo "Protocolo: $([ "$IS_WAYLAND" == "true" ] && echo "Wayland" || echo "X11")"
    echo
    echo "=== COMANDOS PRINCIPAIS ==="
    echo "1. Carregar ambiente:"
    echo "   source '$PREFIX/wine_gaming_env.sh'"
    echo
    echo "2. Executar jogo:"
    echo "   '$PREFIX/wine_run.sh' /caminho/para/jogo.exe"
    echo "   # ou diretamente após carregar o ambiente:"
    echo "   wine /caminho/para/jogo.exe"
    echo
    echo "3. Configurar Wine:"
    echo "   '$PREFIX/configure.sh'"
    echo
    echo "4. Instalar mais programas:"
    echo "   '$PREFIX/install_more.sh'"
    echo
    echo "5. Limpeza do sistema:"
    echo "   '$PREFIX/cleanup.sh'"
    echo
    
    if [[ "$GPU_VENDOR" == "intel" ]]; then
        log_intel "=== DICAS ESPECÍFICAS PARA INTEL ==="
        echo "• Monitore o uso de RAM com DXVK_HUD=memory"
        echo "• Para jogos muito antigos, desabilite DXVK:"
        echo "  WINEDLLOVERRIDES='d3d11=;dxgi=' wine jogo.exe"
        echo "• Se tiver problemas com Vulkan, force OpenGL:"
        echo "  MESA_LOADER_DRIVER_OVERRIDE=i965 wine jogo.exe"
        echo
    fi
    
    if [[ "$IS_WAYLAND" == "true" ]]; then
        log_info "🖥️  === DICAS PARA WAYLAND ==="
        echo "• Alguns jogos podem ter melhor performance no X11"
        echo "• Use 'XDG_SESSION_TYPE=x11' para forçar X11 em uma sessão"
        echo
    fi
    
    log_success "🎮 Ambiente Wine Gaming Optimized pronto para uso!"
}

### EXECUÇÃO PRINCIPAL ###
main() {
    log_info "🍷 Wine Gaming Setup Optimized v4.0"
    echo
    
    detect_system
    check_dependencies
    setup_prefix
    configure_wine
    install_libraries
    install_dxvk
    
    # VKD3D com verificação Intel
    if command -v vulkaninfo &> /dev/null; then
        install_vkd3d
    else
        log_warning "Vulkan não detectado, pulando VKD3D-Proton"
    fi
    
    optimize_performance
    create_utilities
    final_test
    show_instructions
    
    log_success "🎉 Configuração Optimized completa!"
}

# Verificar se está sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
