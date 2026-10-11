# Alterações

## 1.1.3

- Raio redesenhado com canal fractal irregular, oito bifurcações curvas e pequenas derivações; o canal completo acompanha o ponto de impacto na cabeça.
- Núcleo fino e claro com halo vermelho translúcido e espessura variável. Quatro flashes separados substituem o feixe contínuo.
- Mantidos altura, estrondo, chuva e poderes; ajustes não alteram armas, munições ou paralisia.

## 1.1.2

- Tambor e demais peças do dourado fixados ao corpo da arma em todos os LODs, `_hi` e variantes de acabamento.
- Prata: NPCs e jogadores caem em ragdoll relaxado e permanecem no chão durante a paralisia. Removido o congelamento antes da queda, que prendia NPCs em pé/no ar; saída de veículo, renovação da pose e liberação preservadas.
- Raio de 300 metros, feixe mais grosso com três camadas e ramificações, descida até a cabeça, flash/luz e tremor próximos ao impacto.
- Estrondo original em WAV estéreo, reproduzido pela NUI com atenuação por distância e limite de sobreposição, sem explosão física nem dano extra.

## 1.1.1

- Dano em NPC controlado pelo atirador detectado por `entityDamaged`, com validação de arma, série, owner, distância e bucket no servidor. Corrige a dependência exclusiva de `weaponDamageEvent`, que cobre entidades remotas.
- Raio também renderiza pelas coordenadas se o ped ainda não estiver sincronizado; envio limitado ao bucket da vítima.
- Dourado observa a morte replicada do NPC sem depender do campo `willKill`. Fogo tenta novamente caso a criação da partícula falhe.
- Tambor e munições da prata ligados rigidamente ao corpo da arma em todos os LODs, impedindo deslocamento pela animação nativa do cilindro.

## 1.1.0

- Reconstrução dos modelos: eixo do cano, encaixe na mão, esqueleto nativo, pesos de peças móveis e LODs.
- Texturas embutidas, variantes de acabamento e versões de alta qualidade; substituição dos componentes duplicados que apareciam flutuando.
- Efeitos de morte e paralisia em NPCs de rede, com validação no servidor e liberação após o prazo.
- Munições exclusivas Death .1 e Paralisation 0mm, imagens e emissão pelo painel.
- Guia de instalação, uso, compatibilidade e publicação, com prévia DEV.HTML atualizada.

## 1.0.2

- Acesso para administradores dos grupos QBOX/QB/MRI e validação de todas as ações no servidor.

## 1.0.1

- Canvas da NUI transparente e painel oculto até ser aberto; fechamento também oculta diálogos.
