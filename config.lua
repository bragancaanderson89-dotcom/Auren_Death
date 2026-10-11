Config = {
    AdminAce = 'apex.pd.admin',
    -- Permissões nativas e grupos administrativos existentes na QBOX/MRI.
    AdminPermissions = { 'admin', 'god', 'superadmin', 'qadmin.master' },
    AdminGroups = {
        'group.admin', 'group.god', 'group.superadmin',
        'qbcore.admin', 'qbcore.god',
        'mri.group.admin', 'mri.group.god', 'mri.group.superadmin'
    },
    Command = 'apexpd',
    HitRange = 120.0,
    HitCooldownMs = 700,
    DisconnectDelayMs = 6500,
    CarryDistance = 2.5,
    EffectsDistance = 200.0,
    Lightning = { height = 300.0, width = 1.6, durationMs = 2200, thunderVolume = 0.95 },
    RegistryRefreshMs = 15000,
    NPC = { enabled = true, maxActive = 128 },
    Message = 'Você foi morto Permanentemente. Refaça sua HISTÓRIA.',
    -- Armas GTA originais com modelos substituídos. Apenas séries APEX recebem poderes.
    Weapons = {
        gold = { item = 'WEAPON_REVOLVER', hash = joaat('WEAPON_REVOLVER'), label = 'APEX • Sentença', image = 'apex_pd_gold', ammo = 'ammo-apex-death' },
        silver = { item = 'WEAPON_NAVYREVOLVER', hash = joaat('WEAPON_NAVYREVOLVER'), label = 'APEX • Penitência', image = 'apex_pd_silver', ammo = 'ammo-apex-paralisation' }
    },
    Defaults = {
        silverMinutes = 60,
        fire = true,
        fireScale = 0.65,
        lightning = true,
        lightningRed = 255,
        lightningGreen = 24,
        lightningBlue = 40,
        rain = true,
        rainMinutes = 10,
        rainIntensity = 0.8
    },
    -- Adaptador oficial de clima. Pode trocar por vSync, Renewed-Weathersync etc.
    WeatherResource = 'qb-weathersync',
    -- Tabelas adicionais: remoção estritamente por citizenid. Não usa LIKE nem licença.
    -- A lista do qbx_core/config/server.lua já é tratada pelo DeleteCharacter oficial.
    ExtraWipeTables = {
        { table = 'playerskins', column = 'citizenid' },
        { table = 'player_outfits', column = 'citizenid' },
        { table = 'player_vehicles', column = 'citizenid' },
        { table = 'ox_inventory', column = 'owner' }
    },
    -- Para skins com tattoos/overlays extras, implemente o export descrito no LEIA-ME.
    AppearanceResource = 'illenium-appearance',
    Fire = { asset = 'core', effect = 'ent_amb_fbi_fire_wall' },
    Debug = false
}
