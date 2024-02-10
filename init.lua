-- Définir un espace de nom pour le module
warn_system = {}

-- Chemin vers le fichier JSON pour les avertissements
local warns_json_file_path = minetest.get_worldpath() .. "/warns_data.json"

-- Initialiser la variable des avertissements en dehors de load_warns_database
local warns = {}

-- Fonction pour charger la base de données des avertissements
function warn_system.load_warns_database()
    local json_file = io.open(warns_json_file_path, "r")
    if json_file then
        warns = minetest.deserialize(json_file:read("*all"))
        json_file:close()
        minetest.log("action", "[warn_system] Base de données d'avertissements chargée avec succès.")
    else
        -- Créer le fichier JSON s'il n'existe pas
        local new_json_file = io.open(warns_json_file_path, "w")
        new_json_file:write(minetest.serialize(warns))
        new_json_file:close()
        minetest.log("action", "[warn_system] Nouvelle base de données d'avertissements créée.")
    end
end

-- Fonction pour sauvegarder les avertissements dans le fichier JSON
function warn_system.save_warns()
    local json_file = io.open(warns_json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(warns))
        json_file:close()
    end
end

-- fonction pour annuler un avertissement
function warn_system.cancel_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].canceled = true
    warn_system.save_warns()
end

-- fonction pour réactiver un avertissement
function warn_system.reactivate_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].canceled = false
    warn_system.save_warns()
end

-- fonction pour marquer un avertissement comme lu par le joueur
function warn_system.read_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].read = true
    warn_system.save_warns()
end

-- fonction pour marquer un avertissement comme  non  lu par le joueur
function warn_system.unread_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].read = false
    warn_system.save_warns()
end

-- Fonction pour ouvrir un avertissement au joueur dans une interface graphique
-- pour un avertissement spécifique avec un bouton pour le marquer comme lu
-- appelle la fonction warn_system.read_warn pour marquer l'avertissement comme lu
function warn_system.show_warn_formspec(player_name, warn_num)
    local warn_data = warns[player_name]["warn"..warn_num]
    local form = "size[10,8]" ..
        "label[0,0;Avertissement #" .. warn_num .. "]" ..
        "label[0,1;Raison : " .. warn_data.reason .. "]" ..
        "label[0,2;Date : " .. warn_data.date .. "]" ..
        -- Instruction pour marquer l'avertissement comme lu
        "label[0,3;merci de prendre connaissance de cet avertissement]" ..
        "label[0,4;vous pouvez accéder a tout moment au reglement du serveur.]" ..
        "label[0,5; avec la commande /reglement]" ..
        "label[0,6; en cas de non respect de celui-ci, des sanctions pourront etre prise]" ..

        -- Bouton de fermeture et appel à la fonction warn_system.read_warn
        "button_exit[3,7;4,1;read_warn_" .. warn_num .. ";Marquer comme lu]"
    minetest.show_formspec(player_name, "warn_system:show_warn_" .. warn_num, form)
    minetest.chat_send_player(player_name, "Avertissement #" .. warn_num .. " affiché.")
end

-- Fonction pour vérifier et afficher le prochain avertissement non lu
local function check_and_display_next_warning(player_name)
    -- met dans une variable un avertissement non lu et non annulé
    local next_warn
    for warn_num, warn_data in pairs(warns[player_name]) do
        if not warn_data.read and not warn_data.canceled then
            next_warn = tonumber(warn_num:match("%d+"))
            break
        end
    end 
    -- Si un avertissement non lu a été trouvé, appelle la fonction warn_system.show_warn_formspec apres 5 secondes
    if next_warn then
        minetest.after(2, function()
            warn_system.show_warn_formspec(player_name, next_warn)
        end)
    end

end

-- Détecter si le joueur a lu l'avertissement et le marquer comme lu en envoyant un message
minetest.register_on_player_receive_fields(function(player, formname, fields)
    -- Si le formulaire est celui de l'avertissement (warn_system:show_warn_(numéro d'avertissement))
    if formname:find("warn_system:show_warn_") then
        -- Utiliser la fonction warn_system.read_warn pour marquer l'avertissement comme lu
        local warn_num = tonumber(formname:match("(%d+)"))
        local player_name = player:get_player_name()
        warn_system.read_warn(player_name, warn_num)
        -- Envoyer un message dans le chat pour confirmer que l'avertissement a été marqué comme lu
        minetest.chat_send_player(player_name, "Avertissement numéro " .. warn_num .. " marqué comme lu.")
        -- Vérifier et afficher le prochain avertissement non lu
        check_and_display_next_warning(player_name)
    end
end)



-- fonction pour obtenir le nombre d'avertissements d'un joueur
function warn_system.get_num_warns(player_name)
    local player_warns = warns[player_name]
    local num_warns = 0
    if player_warns then
        for _ in pairs(player_warns) do
            num_warns = num_warns + 1
        end
    end
    return num_warns
end




-- commande pour afficher le nombre d'avertissements d'un joueur
minetest.register_chatcommand("num_warns", {
    params = "<joueur>",
    description = "Affiche le nombre d'avertissements d'un joueur",
    func = function(name, param)
        local target_player = param
        if not target_player then
            minetest.chat_send_player(name, "Syntaxe incorrecte. Utilisation: /num_warns <joueur>")
            return
        end
        local num_warns = warn_system.get_num_warns(target_player)
        minetest.chat_send_player(name, "Le joueur " .. target_player .. " a " .. num_warns .. " avertissements.")
    end,
})

-- Fonction pour donner un avertissement à un joueur
function warn_system.give_warn(player_name, reason)
    if not warns[player_name] then
        warns[player_name] = {}
    end
    local num_warns = warn_system.get_num_warns(player_name) + 1
    local warn_num = "warn" .. num_warns
    warns[player_name][warn_num] = {
        date = os.date("%Y-%m-%d %H:%M:%S"),
        reason = reason,
        read = false,
        canceled = false
    }
    warn_system.save_warns()
    minetest.chat_send_player(player_name, "Vous avez reçu un avertissement pour la raison suivante : " .. reason .. ". C'est votre avertissement #" .. num_warns)
    --verifie si le joueur est en ligne et affiche l'avertissement
    if minetest.get_player_by_name(player_name) then
        warn_system.show_warn_formspec(player_name, num_warns)
    end
end

-- commande pour afficher les avertissements spécifiques à un joueur et utiliser la fonction warn_system.show_warn_formspec
minetest.register_chatcommand("show_warn", {
    params = "<joueur> <numéro d'avertissement>",
    description = "Affiche un avertissement spécifique pour un joueur",
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, "Syntaxe incorrecte. Utilisation: /show_warn <joueur> <numéro d'avertissement>")
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, "Le joueur spécifié n'est pas en ligne.")
            return
        end
        if not warns[target_player] or not warns[target_player]["warn"..warn_num] then
            minetest.chat_send_player(name, "Avertissement non trouvé.")
            return
        end
        warn_system.show_warn_formspec(target_player, tonumber(warn_num))
    end,
})

-- commande pour annuler un avertissement
minetest.register_chatcommand("cancel_warn", {
    params = "<joueur> <numéro d'avertissement>",
    description = "Annule un avertissement donné à un joueur",
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, "Syntaxe incorrecte. Utilisation: /cancel_warn <joueur> <numéro d'avertissement>")
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, "Le joueur spécifié n'est pas en ligne.")
            return
        end
        warn_system.cancel_warn(target_player, tonumber(warn_num))
        minetest.chat_send_player(name, "Avertissement #" .. warn_num .. " annulé pour le joueur " .. target_player)
    end,
})

-- commande pour réactiver un avertissement
minetest.register_chatcommand("reactivate_warn", {
    params = "<joueur> <numéro d'avertissement>",
    description = "Réactive un avertissement annulé pour un joueur",
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, "Syntaxe incorrecte. Utilisation: /reactivate_warn <joueur> <numéro d'avertissement>")
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, "Le joueur spécifié n'est pas en ligne.")
            return
        end
        warn_system.reactivate_warn(target_player, tonumber(warn_num))
        minetest.chat_send_player(name, "Avertissement #" .. warn_num .. " réactivé pour le joueur " .. target_player)
    end,
})

-- commande pour marquer un avertissement comme lu par le joueur
minetest.register_chatcommand("read_warn", {
    params = "<joueur> <numéro d'avertissement>",
    description = "Marque un avertissement comme lu pour un joueur",
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, "Syntaxe incorrecte. Utilisation: /read_warn <joueur> <numéro d'avertissement>")
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, "Le joueur spécifié n'est pas en ligne.")
            return
        end
        warn_system.read_warn(target_player, tonumber(warn_num))
        minetest.chat_send_player(name, "Avertissement #" .. warn_num .. " marqué comme lu pour le joueur " .. target_player)
    end,
})

-- Commande pour donner un avertissement à un joueur
minetest.register_chatcommand("warn", {
    params = "<joueur> <raison>",
    description = "Donne un avertissement à un joueur",
    func = function(name, param)
        local target_player, reason = param:match("(%S+)%s+(.+)")
        if not target_player or not reason then
            minetest.chat_send_player(name, "Syntaxe incorrecte. Utilisation: /warn <joueur> <raison>")
            return
        end
        warn_system.give_warn(target_player, reason)
        minetest.chat_send_player(name, "Avertissement donné à " .. target_player .. " pour la raison suivante : " .. reason)
    end,
})

-- Commande pour voir tous les avertissements d'un joueur
minetest.register_chatcommand("warns", {
    params = "<joueur>",
    description = "Affiche tous les avertissements d'un joueur",
    func = function(name, param)
        local target_player = param
        if not target_player then
            minetest.chat_send_player(name, "Syntaxe incorrecte. Utilisation: /view_warns <joueur>")
            return
        end
        local player_warns = warns[target_player]
        if not player_warns then
            minetest.chat_send_player(name, "Ce joueur n'a aucun avertissement.")
            return
        end
        minetest.chat_send_player(name, "Avertissements pour le joueur " .. target_player .. ":")
        for warn_num, warn_data in pairs(player_warns) do
            local status = warn_data.read and "Lu" or "Non lu"
            local canceled = warn_data.canceled and "Annulé" or "Actif"
            minetest.chat_send_player(name, "Avertissement #" .. warn_num .. " - Raison : " .. warn_data.reason .. " - Date : " .. warn_data.date .. " - Statut : " .. status .. " - " .. canceled)
        end
    end,
})


-- quand un joueur se connecte, vérifie et affiche le prochain avertissement non lu
minetest.register_on_joinplayer(function(player)
    local player_name = player:get_player_name()
    local next_warn
    for warn_num, warn_data in pairs(warns[player_name]) do
        if not warn_data.read and not warn_data.canceled then
            next_warn = tonumber(warn_num:match("%d+"))
            break
        end
    end 
    -- Si un avertissement non lu a été trouvé, appelle la fonction warn_system.show_warn_formspec apres 5 secondes
    if next_warn then
        minetest.after(1, function()
            warn_system.show_warn_formspec(player_name, next_warn)
        end)
    end
end)

-- Charger la base de données des avertissements au démarrage
warn_system.load_warns_database()
