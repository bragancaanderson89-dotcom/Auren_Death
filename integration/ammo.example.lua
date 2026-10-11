-- Mesclar em ox_inventory/data/weapons.lua. Atualizar as armas EXISTENTES;
-- inserir as duas munições em Ammo, sem duplicar as chaves.
return {
    Weapons = {
        ['WEAPON_REVOLVER'] = { ammoname = 'ammo-apex-death' },
        ['WEAPON_NAVYREVOLVER'] = { ammoname = 'ammo-apex-paralisation' }
    },
    Ammo = {
        ['ammo-apex-death'] = { label = 'Death .1', weight = 15, client = { image = 'ammo-apex-death.png' } },
        ['ammo-apex-paralisation'] = { label = 'Paralisation 0mm', weight = 15, client = { image = 'ammo-apex-paralisation.png' } }
    }
}
