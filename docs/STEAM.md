# Preparação para a Steam

O alvo comercial é a Steam (Windows e Linux; Steam Deck via Linux nativo).

## Já pronto

- Exports de release Windows x86_64 (`.exe` com PCK embutido) e Linux x86_64, gerados e testados no CI.
- Jogo 100% offline. Salvamentos em `user://saves` (Windows `%APPDATA%\Godot\app_userdata\Last Industry`,
  Linux `~/.local/share/godot/app_userdata/Last Industry`). Compatível com Steam Cloud por caminho.
- Controles de teclado e mouse, resolução escalável (`canvas_items` + `expand`).

## Checklist até a página da loja

1. **Steamworks:** pagar a taxa de app (Steam Direct), obter o **App ID**, criar depots Windows e Linux.
2. **GodotSteam:** adicionar o plugin GDExtension [GodotSteam](https://godotsteam.com) compatível com
   Godot 4.3 em `addons/godotsteam`. Criar um autoload `SteamService` que:
   - inicializa com `Steam.steamInitEx()` e degrada para modo offline se a Steam não estiver aberta;
   - chama `Steam.run_callbacks()` por frame;
   - expõe `unlock(achievement_id)` e `set_stat()` (no-op fora da Steam).
   Manter a simulação sem conhecimento da Steam: conquistas reagem a `world.events`.
3. **Conquistas iniciais:** primeira munição automatizada, sobreviver à horda 1/5/10, derrotar o chefe,
   100 abates, base sem perder estruturas numa horda, horda 20 no modo Sobrevivência.
4. **Steam Cloud:** configurar Auto-Cloud com raiz `WinAppDataRoaming` (`Godot/app_userdata/Last Industry/saves`)
   e equivalente Linux.
5. **Builds:** `steam_appid.txt` só em desenvolvimento (nunca no depot). Upload com `steamcmd` +
   scripts VDF (`app_build_<appid>.vdf`) a partir dos artefatos do CI. Branch `beta` para playtests.
6. **Steam Deck:** testar no modo Compatibility/Vulkan, fonte mínima legível a 1280×800, layout de
   controle (Steam Input) com mapeamento para construção.
7. **Loja:** cápsulas (header 460×215, small 231×87, main 616×353, vertical 374×448, library 600×900),
   5+ screenshots, trailer com o ciclo produzir → defender → reconstruir, descrição curta:
   *“Construa uma fábrica automatizada capaz de sobreviver às criaturas que ela mesma desperta.”*
8. **Localização:** extrair textos para `.po`/CSV (pt-BR atual, depois EN e ES).
9. **Requisitos mínimos** (estimativa a validar): CPU 4 núcleos 2,5 GHz, 8 GB RAM, GPU com Vulkan 1.1
   (fallback OpenGL 3.3), 500 MB de disco.

## Ainda não feito

Nenhum SDK da Steam está no repositório. O App ID e os binários do Steamworks dependem da sua conta
de desenvolvedor.
