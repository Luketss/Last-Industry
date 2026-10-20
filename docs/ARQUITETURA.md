# Arquitetura

```
src/
  main.gd                  Aplicação: estados (menu/jogo), laço de tick fixo, atalhos globais, salvar/carregar
  sim/                     SIMULAÇÃO — GDScript puro, sem nós de cena, determinística
    defs.gd                Constantes (tick 20 Hz, direções, terrenos)
    game_data.gd           Carrega data/*.json (conteúdo configurável)
    world.gd               Estado autoritativo: grade, estruturas, inimigos, estoque, eventos, salvar
    building.gd, enemy.gd  Estado de entidades
    map_generator.gd       Terreno procedural, jazidas, ninhos, corredores garantidos
    save_system.gd         Arquivos locais em user://saves
    systems/
      power_system.gd      Redes elétricas, prioridades, geradores, baterias
      logistics_system.gd  Esteiras, saídas de máquinas, divisores, coleta adjacente
      production_system.gd Mineradoras e máquinas de receita
      pathfinding.gd       Campos de fluxo (Dijkstra) por perfil de inimigo
      enemy_system.gd      Movimento, seleção de alvo, ataque, dano em área
      combat_system.gd     Torres balística/elétrica, estação de reparo
      wave_system.gd       Hordas anunciadas, patrulhas, sobrevivência, ciclo noite
      stats.gd             Produção/consumo com janela móvel de 1 minuto
      objectives.gd        Objetivos guiados, recompensas, gatilhos narrativos
  view/                    APRESENTAÇÃO — lê a simulação, nunca decide regras
    world_view.gd          Ambiente, terreno, estruturas, MultiMesh de itens/inimigos, efeitos, depuração
    meshes.gd              Modelos procedurais e materiais
    camera_rig.gd          Câmera isométrica ortográfica
    build_controller.gd    Entrada de construção → comandos no World
    audio.gd               Paisagem sonora procedural
  ui/                      Interface (HUD, menus, painéis)
data/                      Conteúdo: estruturas, receitas, itens, inimigos, hordas, objetivos, narrativa
tests/                     Testes headless (unidade, integração, desempenho)
```

## Princípios

1. **Simulação separada da renderização.** `World.step()` avança um tick fixo (1/20 s). A view só lê
   estado e consome `world.events` (disparos, mortes, construções) para efeitos. Por isso a simulação
   roda inteira em testes headless e no teste de fumaça do CI.
2. **Determinismo.** RNG com semente, iteração em ordem de inserção e campos de fluxo dependentes só do
   layout. Salvar e carregar continua a partida de forma idêntica (`test_save.gd`). O formato de
   salvamento é binário (`store_var`) porque o parser JSON do Godot não preserva doubles exatamente.
3. **Dados configuráveis.** Qualquer estrutura nova é um registro em `data/buildings.json` com um
   `kind` existente (`crafter`, `turret_gun`, ...). Receitas, inimigos e hordas são só dados.
4. **Sistemas independentes.** Cada sistema recebe o `World` e opera sobre listas por tipo
   (`world.list("belt")`), reconstruídas apenas quando a estrutura muda.

## Ordem de um tick

```
reconstruir caches sujos (logística, energia)
→ pedidos de energia (produção, combate)
→ resolver energia por rede (prioridade defesa → produção, baterias, combustível)
→ produção (mineração, receitas)
→ logística (saídas → esteiras → coleta adjacente)
→ campos de fluxo (no máx. 2×/s, só se o layout mudou)
→ inimigos → combate → remover mortos
→ hordas → estatísticas → objetivos
```

## Regras dos sistemas

- **Itens:** máquinas empurram produtos pela saída (seta). Esteiras entregam ao que estiver à frente.
  Torres, geradores e estações de reparo também puxam o que aceitam de esteiras encostadas
  (`"pull": true` e `"accepts"` nos dados). O Núcleo aceita tudo.
- **Energia:** nós (postes, Núcleo) se ligam se a distância for menor que o alcance de fio de ambos.
  Uma estrutura está conectada se algum tile cai na área de suprimento de um nó. Cada componente
  conexo é uma rede independente. Demanda prioridade 0 (defesa/reparo) é atendida antes da 1 (produção).
- **Navegação:** campo de fluxo por perfil. Custo de entrar numa célula com estrutura =
  `1 + hp_max/50 × wall_weight`. Corredores (peso 4) contornam, Aríetes (0,25) atravessam. Quem
  encontra uma estrutura na rota a ataca. Rastejantes também mordem estruturas próximas (aggro).

## Desempenho

- Itens em esteiras, inimigos e barras de vida são desenhados com `MultiMesh` (uma chamada por tipo).
- Projéteis são hitscan com traçadores em `ImmediateMesh`.
- Orçamento verificado em teste: tick < 25 ms com 264 estruturas e 150 inimigos (medido: ~1,7 ms).

## Depuração

- **F3:** setas do campo de fluxo, ligações das redes elétricas, alvo de cada inimigo e torre.
- **Tab:** produção/consumo por minuto, estado de cada rede, contagem de máquinas por estado
  (gargalos), esteiras congestionadas.
- `godot --headless --path . -- --smoke [--screenshots=DIR]`: roda o ciclo completo e captura telas.
