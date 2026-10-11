-- Exemplos para ox_inventory/data/weapons.lua, dentro da tabela Weapons.
-- Não inserir se a chave já existir. Os nomes/imagens dos artefatos são metadata.
return {
    Weapons = {
        ['WEAPON_REVOLVER'] = {
            label = 'APEX • Sentença', weight = 2200, durability = 0.1, ammoname = 'ammo-apex-death',
            anim = { 'reaction@intimidation@1h', 'intro', 1200, 'reaction@intimidation@1h', 'outro', 1400 }
        },
        ['WEAPON_NAVYREVOLVER'] = {
            label = 'APEX • Penitência', weight = 2200, durability = 0.1, ammoname = 'ammo-apex-paralisation',
            anim = { 'reaction@intimidation@1h', 'intro', 1200, 'reaction@intimidation@1h', 'outro', 1400 }
        }
    }
}
