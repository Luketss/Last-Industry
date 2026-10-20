# Distribuição: builds de teste e Steam

O alvo comercial é a Steam (Windows e Linux; Steam Deck via Linux nativo). Tudo abaixo, exceto o
que depende da sua conta Steamworks, já está no repositório.

## Builds de teste (pronto)

| Como | O que gera |
|---|---|
| Cada push / PR (`ci.yml`) | Testes, teste de fumaça, builds Windows e Linux como artefatos do Actions |
| `scripts/build.sh [versão]` | `build/release/LastIndustry-<versão>-windows-x86_64.zip`, `-linux-x86_64.tar.gz` e `SHA256SUMS.txt`. O binário Linux exportado é testado com `--smoke` antes de empacotar |
| Tag `vX.Y.Z` (`release.yml`) | Carimba a versão no jogo e no .exe, roda testes, empacota e publica um **GitHub Release** (tags com sufixo, como `v0.3.0-beta.1`, viram pré-release) |
| Execução manual do `release.yml` | Mesmos pacotes como artefato, sem publicar release (útil para playtests) |

Logs de execução do jogo (para relatórios de bugs dos testadores): `user://logs/godot.log`
- Windows: `%APPDATA%\Godot\app_userdata\Last Industry\logs\`
- Linux: `~/.local/share/godot/app_userdata/Last Industry/logs/`

## Integração Steam no jogo (pronto, inativa até configurar)

- `src/platform/steam_service.gd` usa o **GodotSteam** se o plugin estiver instalado e houver App ID.
  Sem isso, todas as chamadas são inofensivas e o jogo roda offline (testado em `test_platform.gd`).
- **Conquistas** (`data/achievements.json`, 12 no total) são avaliadas a partir das estatísticas da
  partida, salvas localmente em `user://achievements.cfg` e espelhadas na Steam com
  `setAchievement` + `storeStats`. Os `id`s já estão no formato da Steam (MAIÚSCULAS).
- **Rich Presence:** “Horda N · M estruturas”.
- Menu principal e pausa têm a tela **Conquistas**, que mostra o estado da conexão com a Steam.

## Passo a passo para publicar

1. **Steamworks:** pague o Steam Direct, crie o app e anote o **App ID**. Crie dois depots:
   Windows (`App ID + 1`) e Linux (`App ID + 2`). Essa numeração é a que o CI espera.
2. **Conquistas na Steam:** em *Stats & Achievements*, crie as 12 conquistas com os mesmos API names
   de `data/achievements.json` (FIRST_LINE, FIRST_NIGHT, WAVE_5, CAMPAIGN, BOSS, KILLS_500, FLAWLESS,
   RESEARCH_ALL, GENESIS, POWER_1000, FACTORY_500, SURVIVAL_20) e publique.
3. **GodotSteam:** baixe a versão GDExtension compatível com Godot 4.3 em <https://godotsteam.com>,
   extraia em `addons/godotsteam/` e habilite. Em *Project Settings › steam/app_id*, coloque o App ID
   (para testes locais, `480` é o app de teste da Valve).
4. **Teste local:** com a Steam aberta, rode pelo editor; a tela Conquistas deve mostrar
   “Steam: conectado”. Em desenvolvimento, `steam_appid.txt` ao lado do executável (os depots excluem
   esse arquivo).
5. **Upload pelo CI:** em *Settings › Secrets and variables › Actions* do repositório:
   - variável `STEAM_ENABLED` = `true`
   - segredos `STEAM_USERNAME` (conta de build, sem ser a conta principal), `STEAM_APP_ID` e
     `STEAM_CONFIG_VDF`. Para gerar este último, faça login uma vez com `steamcmd +login <conta>`,
     informe o Steam Guard e codifique `config/config.vdf` em base64.
   Tags com sufixo vão para o branch **beta** da Steam automaticamente. Versões estáveis são enviadas
   sem ir ao ar: publique no painel do Steamworks (a Steam não permite ativar o branch padrão por script).
6. **Upload manual (alternativa):** `scripts/build.sh` e depois
   `STEAM_USERNAME=... STEAM_APP_ID=... STEAM_DEPOT_WINDOWS=... STEAM_DEPOT_LINUX=... STEAM_BRANCH=beta scripts/steam_upload.sh`
   (usa os modelos `steam/*.vdf`).
7. **Steam Cloud:** Auto-Cloud com raiz `WinAppDataRoaming` + `Godot/app_userdata/Last Industry/saves`
   (Windows) e `LinuxHome` + `.local/share/godot/app_userdata/Last Industry/saves` (Linux), padrão `*.lisave`.
8. **Página da loja:** cápsulas (header 460×215, small 231×87, main 616×353, vertical 374×448, library
   600×900), 5+ capturas, trailer com o ciclo produzir → defender → reconstruir. Descrição curta:
   *“Construa uma fábrica automatizada capaz de sobreviver às criaturas que ela mesma desperta.”*
9. **Requisitos mínimos** (a validar em playtest): CPU 4 núcleos 2,5 GHz, 8 GB RAM, GPU com Vulkan 1.1
   (o modo Compatibility/OpenGL 3.3 também roda), 500 MB de disco.

## Ainda pendente

- **Steam Deck / controle:** o jogo ainda é teclado e mouse. Para o selo “Verificado” é preciso
  suporte a controle (cursor virtual + rodas de construção) e interface legível em 1280×800.
- **Localização:** a interface e o conteúdo estão em pt-BR. Inglês e espanhol ampliam muito o
  alcance na Steam; os textos de conteúdo já estão concentrados em `data/*.json`.
- **Ícone do .exe:** exportar com ícone a partir do Linux exige o `rcedit` (ou exportar no Windows).
