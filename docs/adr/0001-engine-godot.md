# ADR 0001 — Engine: Godot 4 (GDScript)

**Status:** aceito · **Data:** 2026-10

## Contexto

Precisamos de um jogo 3D isométrico para Windows e Linux, publicável na Steam, com: muitos itens em
esteiras, dezenas de máquinas, centenas de inimigos e projéteis; construção precisa em grade;
simulação testável e reproduzível; equipe pequena.

## Opções

| Critério | Godot 4.3 | Unity 6 |
|---|---|---|
| Linux (editor e export) | Nativo, primeira classe | Suportado, menos testado |
| Licença / custos | MIT, sem royalties nem taxas | Planos pagos acima de receita; histórico recente de mudanças de licença |
| Builds em CI | Binário único + templates; export headless trivial | Requer licença ativada no runner |
| Testes headless | `--headless` roda a simulação sem GPU | Possível, mais configuração |
| Desempenho bruto | GDScript é mais lento que C# | C#/Burst/DOTS muito rápido |
| Steam | GodotSteam (GDExtension, MIT) | Steamworks.NET / Facepunch |
| Ferramentas 3D/assets | Suficientes para estilo low-poly | Ecossistema maior (Asset Store) |

## Decisão

**Godot 4.3** com GDScript, renderizador Forward+ (Vulkan) e fallback Compatibility (OpenGL).

- Licença MIT elimina risco comercial e de royalties para um lançamento independente na Steam.
- Exportação e testes headless simples em Linux, que é também plataforma alvo.
- A simulação foi isolada da renderização e roda em ticks fixos de 20 Hz. Medimos ~1,7 ms por
  tick com 264 estruturas e 150 inimigos (`test_simulation_performance_budget`), bem dentro do orçamento.
- Se a escala do jogo final exigir, sistemas quentes (esteiras, fluxo de campo) podem migrar para
  C++ via GDExtension sem mudar a arquitetura, porque a simulação já é uma camada separada.

## Consequências

- Precisamos vigiar o custo por tick de GDScript conforme o conteúdo cresce (há teste de orçamento).
- A integração Steam será feita com GodotSteam (ver `docs/STEAM.md`).
- Versão de engine fixada em 4.3 no CI. Atualizações são decisões explícitas.
