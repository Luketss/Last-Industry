# Créditos dos recursos de terceiros

Todos os recursos abaixo vêm do [OpenGameArt.org](https://opengameart.org). Os pacotes da Kenney
também são distribuídos pelo [itch.io](https://kenney.itch.io) com a mesma licença. A lista legível
por máquina fica em [`sources.json`](sources.json); o jogo a exibe em **Menu › Créditos**.

| Uso no jogo | Pacote | Autor | Licença |
|---|---|---|---|
| Estruturas (máquinas, caixas, braços robóticos) | [Factory Kit](https://opengameart.org/content/factory-kit) | Kenney | CC0 |
| Torres e bases das torres | [Tower Defense Kit](https://opengameart.org/content/tower-defense-kit) | Kenney | CC0 |
| Núcleo, gerador, painel solar, ruínas do mapa | [City Kit (Industrial)](https://opengameart.org/content/city-kit-industrial) | Kenney | CC0 |
| Molduras de painéis e botões, fonte Kenney Future | [UI Pack - Sci-Fi](https://opengameart.org/content/ui-pack-sci-fi) | Kenney | CC0 |
| Inimigos (Rastejante, Corredor, Aríete, Sabotador, Planador) | [50+ Monsters Pack 3D](https://opengameart.org/content/50-monsters-pack-3d) | isaiah658 | CC0 |
| Ícones dos itens (minério, placa, componente, pacotes, projétil) | [Different Sci-Fi Item Icons](https://opengameart.org/content/different-sci-fi-item-icons) | CraftPix.net | OGA-BY 3.0 |
| Ícone do pente de munição | [Free Set of 10 Post-apocalypse Icons](https://opengameart.org/content/free-set-of-10-post-apocalypse-icons) | CraftPix.net | OGA-BY 3.0 |
| Ícones dos menus | [Game Icons](https://opengameart.org/content/game-icons) | Kenney | CC0 |
| Tiros, explosões, descarga elétrica, alerta | [Sci-Fi Sounds](https://opengameart.org/content/sci-fi-sounds) | Kenney | CC0 |
| Cliques, construção, objetivos, conquistas | [Interface Sounds](https://opengameart.org/content/interface-sounds) | Kenney | CC0 |
| Música do menu | [Tragic ambient main menu](https://opengameart.org/content/tragic-ambient-main-menu) | HaelDB | CC0 |
| Música ambiente | [EmptyCity: Background Music](https://opengameart.org/content/emptycity-background-music) | yd | CC0 |
| Música ambiente | [Factory ambiance](https://opengameart.org/content/factory-ambiance) | yd | CC0 |
| Música ambiente | [Lone Scavenger](https://opengameart.org/content/lone-scavenger) | vitalezzz | CC0 |
| Música ambiente | [Iron wasteland](https://opengameart.org/content/iron-wasteland) | Alexandr Zhelanov | CC-BY 4.0 |
| Música das hordas finais, com chefe e da ativação de Genesis | [Boss Battle #9 [Metal]](https://opengameart.org/content/boss-battle-9-metal) | nene | CC0 |
| Música das hordas | [Cyborg Factory Fight Theme](https://opengameart.org/content/cyborg-factory-fight-theme) | GTDStudio (Palrom) | OGA-BY 3.0 |

As licenças CC-BY 4.0 e OGA-BY 3.0 exigem atribuição, feita na tela de créditos e neste arquivo.
Nenhum recurso com cláusula *share-alike* (CC-BY-SA, GPL) foi usado, para não restringir a
distribuição comercial na Steam.

## Modificações

- Os modelos 3D usam um atlas de cores recolorido (`models/*/Textures/colormap.png`) para a paleta
  enferrujada e dessaturada do jogo.
- As paletas dos monstros foram dessaturadas e escurecidas (`models/enemies/*.png`).
- As molduras de interface foram remapeadas para as cores do tema (`ui/*.png`).
- Músicas e sons foram normalizados em volume (EBU R128) e convertidos para Ogg Vorbis.
- Os ícones da barra de construção (`icons/buildings/`) são renderizados a partir dos próprios
  modelos do jogo por `scripts/render_icons.gd`.

Tudo é regenerado por `python3 scripts/import_assets.py`, que baixa os pacotes originais.
