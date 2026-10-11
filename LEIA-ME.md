# Auren_Death — MRI QBOX

Resource FiveM com revólver dourado **Sentença**, revólver prateado **Penitência**, painel administrativo NUI e imagens renderizadas dos GLBs fornecidos.

**Versão 1.1.0:** o guia principal atualizado está em [README.md](README.md), incluindo munições exclusivas, NPCs, variantes `_hi`, instalação e uso. Este arquivo detalha as integrações de PD/corpos/WIPE.

## Instalar

1. Copie **esta pasta `Auren_Death`** para `resources/[apex]/Auren_Death`.
2. Copie as imagens dos dois revólveres e `ammo-apex-death.png` / `ammo-apex-paralisation.png` de `web/assets` para `ox_inventory/web/images/`. Configure Weapons/Ammo conforme `integration/ammo.example.lua` e README.
3. No `server.cfg`, após seus recursos principais, adicione:

```cfg
setr inventory:weaponanims true
ensure Auren_Death
```

Necessários: **OneSync**, `qbx_core`, `oxmysql`, `ox_lib`, `ox_inventory`, `ox_target`. Use game build **2060 ou superior**, que inclui o Navy Revolver. As tabelas SQL do APEX são criadas automaticamente pelo oxmysql; `install.sql` também está disponível para instalação manual.

4. Confirme que `ox_inventory/data/weapons.lua` contém `WEAPON_REVOLVER` e `WEAPON_NAVYREVOLVER`. Em versões normais, ambos já existem. Caso faltem, veja `integration/weapons.example.lua`: os blocos entram **dentro de `Weapons`**, nunca em `items.lua`. Não duplique entradas existentes.

Altere o `ammoname` desses dois blocos para as munições exclusivas. Reinicie o servidor após mudar o ox_inventory e reconecte o FiveM para atualizar modelos e munições.
5. Reinicie o servidor e abra **`/apexpd`** com um administrador da base. O APEX aceita automaticamente as ACEs `admin`, `god`, `superadmin`, `qadmin.master` e os grupos administrativos configurados em `Config.AdminGroups`, incluindo os grupos admin/god do MRI Qadmin. Não exige cadastrar uma permissão APEX separada para cada administrador. Emita os revólveres pelo painel; não utilize `giveitem` para criar poderes, pois armas comuns não possuem a série APEX registrada.

Grupos personalizados podem ser adicionados em `Config.AdminGroups`; a ACE exclusiva `apex.pd.admin` continua disponível para acessos específicos. A associação automática usa `lib.addAce`, com as permissões normais de ACL do ox_lib já exigidas pela QBOX. Promoções e remoções de grupo valem na próxima ação. Moderadores/suportes não recebem acesso apenas por terem `qadmin.open` ou uma permissão de comando isolada. Para exigir somente a ACE exclusiva, deixe `AdminPermissions` e `AdminGroups` vazios.

As animações de sacar/guardar e recarregar são as nativas utilizadas pelo ox_inventory. Não há um segundo sistema de equipar competindo com ele. `illenium-appearance` é o adaptador padrão para aparência completa do corpo; há captura básica de roupa/rosto quando o export não estiver disponível.

## Prévia

Abra **`DEV.HTML`** nesta pasta. Funciona com duplo clique, sem npm, servidor HTTP ou internet. Usa os mesmos CSS e JavaScript da NUI, com dados fictícios. Permite emitir/revogar, pesquisar, alterar os efeitos e liberar uma suspensão na demonstração. Nada na prévia altera banco ou servidor. A versão na pasta superior `Apex_PD/DEV.HTML` também funciona.

## Comportamento

### Dourado / Sentença

- Somente uma arma registrada e não revogada aplica PD.
- Recarga exclusiva: Death .1 (`ammo-apex-death`).
- Um **disparo fatal** produz raio vermelho diretamente na cabeça, chuva sincronizada e a tela de sentença. Acertos não fatais causam apenas o dano normal do revólver.
- O evento de dano do motor é validado no servidor: item equipado, hash, série, distância, bucket, vítima e fatalidade replicada. `willKill` isolado não dispara WIPE.
- O servidor cria outro ped OneSync e captura a aparência da vítima. Esse ped representa o cadáver; o ped do jogador que desconecta não é usado como corpo persistente.
- Após 6,5 segundos, o core descarrega o personagem, o jogador é desconectado com **“Você foi morto Permanentemente. Refaça sua HISTÓRIA.”**, e a exclusão individual é executada por `qbx_core:DeleteCharacter(citizenid)`.
- O cadastro de conta/licença e outros personagens da conta não são excluídos. O `citizenid` morto fica em um registro mínimo de sentença/auditoria para impedir que um WIPE incompleto permita seu retorno.
- O corpo é um ped **cenográfico** protegido, em animação nativa de morto: mantém vida técnica para que o GTA permita animar e carregar. Possui o statebag `apexPdBody` para que scripts externos o reconheçam como cadáver e o excluam de funções de cura/IA.
- Use o ox_target próximo ao corpo para carregar/colocar no chão. **E** coloca o corpo no chão durante o transporte. É possível montar velórios e cerimônias com esse corpo. Ele existe até o restart do servidor **ou do resource**; não é salvo como personagem no banco.

### Prateado / Penitência

- Ao atingir um jogador, cancela o dano normal do tiro e aplica **60 minutos** de incapacitação por padrão.
- Recarga exclusiva: Paralisation 0mm (`ammo-apex-paralisation`).
- Prazo salvo por `citizenid`, com término absoluto. Reconectar e reiniciar não reiniciam a hora; o tempo offline também conta.
- Chamas visuais durante a suspensão, sem dano térmico nem propagação de incêndios. Fogo nativo causaria morte, expiraria e impediria o efeito contínuo solicitado.
- Impede movimentação, uso de arma/inventário e ações físicas; câmera, chat e voz permanecem disponíveis. Administradores podem encerrar o prazo.
- Novos acertos não encurtam uma suspensão existente. Mudanças de duração no painel valem para os próximos acertos.

## Painel administrativo

Visão geral, arsenal, suspensões, efeitos/regras e histórico. Permite emissão, revogação, localização no mapa, prazo de incapacitação, intensidade das chamas, ativação/cor RGB do raio, chuva/intensidade/duração e liberação administrativa. Todas as callbacks verificam ACE no servidor; abrir um HTML ou forjar uma chamada NUI não concede acesso.

O rastreamento confirma inventários carregados e guarda a última posição do portador/depósito. Em versões antigas do ox_inventory sem `GetInventories`, acompanha jogadores e inventários vistos pelos hooks. Depósitos fechados e personagens offline exibem a última localização registrada: **não é telemetria em tempo real de inventários descarregados**. A revogação bloqueia poderes imediatamente e remove itens dos inventários carregados; inventários offline são limpos quando carregarem.

## WIPE e integrações da sua cidade

O export do core usa a lista `characterDataTables` da sua instalação. Verifique `qbx_core/config/server.lua` para incluir todos os sistemas pessoais da cidade. Além da lista do core, `Config.ExtraWipeTables` remove skins, outfits, veículos e inventários privados por identificador exato. Tabelas que não existem são ignoradas. Para telefone, banco externo, imóveis, pets e MDT personalizados, acrescente os pares de tabela/coluna corretos da **sua** instalação; IDs de telefone ou IDs numéricos precisam de um adaptador específico, não podem ser tratados como citizenid.

O core é descarregado **antes** da exclusão para impedir autosave de recriar o personagem. A exclusão oficial é assíncrona: o APEX consulta o banco até confirmar ausência em `players`, depois conclui a transação das tabelas adicionais. Falhas são registradas, mantêm o personagem bloqueado e voltam à fila a cada minuto/restart. O histórico mostra a falha e permite tentar novamente. A exclusão do core e dos módulos adicionais não forma uma única transação global; a fila trata esse intervalo explicitamente.

Clima: compatível com a camada `qb-weathersync` do **Renewed-Weathersync** da MRI, além da sobreposição de tempestade do próprio APEX em todos os clientes. Recursos de clima personalizados podem exigir ajuste em `Config.WeatherResource`. A sobreposição termina ao expirar o período ou parar o resource. Instâncias/buckets não recebem o raio de uma vítima que não está disponível no cliente; a chuva é global à cidade.

Skin completa: o resource chama `getPedAppearance(ped)` e `setPedAppearance(ped, appearance)` do recurso definido em `Config.AppearanceResource`. Para outro sistema, adapte essas duas chamadas em `client/main.lua`. Corpos trazem roupas, acessórios e, via illenium, blends, tatuagens e overlays.

## Modelos e texturas

- **`w_pi_revolver.ydr`** substitui o visual de `WEAPON_REVOLVER`.
- **`w_pi_wep2_gun.ydr`** substitui o visual de `WEAPON_NAVYREVOLVER`.
- Isso altera a aparência desses dois tipos de arma na cidade; os poderes continuam exclusivos das séries emitidas pelo APEX. Não são novos hashes de arma/add-on.
- Conversão binária real com Blender + Sollumz + szio/PyMateria; arquivos RSC7, sem renomear GLB para YDR.
- HIGH preserva a geometria original. MEDIUM/LOW/VERYLOW têm versões reduzidas, com UVs e tangentes.
- Cor, normal e material metálico convertidos para DDS, com mipmaps e referências verificadas por releitura do binário.
- Dourado preserva texturas **512 px** da origem. Prateado preserva cor/material **4K**, com normais **2K**. Mapas 4K são separados em dicionários **`+hidr.ytd`**; mantenha TODOS os arquivos de `stream` juntos.
- O material glTF PBR é convertido para `normal_spec.sps` do GTA; o sistema de materiais é diferente e a iluminação do jogo pode variar do render de estúdio.
- Para OpenIV, feche/reabra o modelo após atualizar. O YDR contém as texturas de resolução base; os dicionários em `tools/OpenIV_textures` da pasta superior servem como referência de inspeção. Os PNGs do inventário são renderizações dos GLBs originais.
- Confirme posição na mão e recarga em jogo. A conversão utiliza o esqueleto nativo de cada revólver. Todas as peças acompanham rigidamente o corpo da arma, evitando deslocamento dos tambores pela montagem diferente das animações mecânicas GTA. A correspondência dos ossos e variantes foi verificada nos arquivos; as animações do personagem ainda precisam de homologação no FiveM.

## Validação entregue

- Sintaxe dos scripts Lua compilada em **Lua 5.4**.
- Cenários com simulação de QBOX/ox: rejeição de hash/melee/série revogada, fatalidade falsa, suspensão forjada, permissões ACE, valores inválidos, remoção e ordem corpo → logout → desconexão → WIPE.
- Navegador real: prévia, imagens, busca, emissão, revogação, persistência local de efeitos, liberação, histórico e resolução de 960×640.
- YDRs reabertos com szio: canais ligados, DDS embutidos e mipmaps; alta resolução verificada nos dicionários HD.

**Não houve execução em um servidor FiveM/MRI nem conexão ao banco da sua cidade.** Esses testes não substituem uma homologação do hospital, anticheat, clima e aparência. Em homologação, use personagens de teste para conferir fatalidade, exclusão, reconexão, troca de portador, buckets, transporte de corpo e restart.

Referências técnicas: [QBOX — exports](https://docs.qbox.re/resources/qbx_core/exports/server), [ox_inventory — hooks](https://overextended.dev/docs/ox_inventory/Functions/Server/Hooks), [Cfx — eventos](https://docs.fivem.net/docs/scripting-reference/events/server-events/), [Cfx — armas/modelos](https://docs.fivem.net/docs/game-references/weapon-models/), [MRI — Renewed-Weathersync](https://www.mriqbox.com.br/docs/mri/resources/Renewed-Weathersync), [Sollumz](https://github.com/Sollumz/Sollumz).
