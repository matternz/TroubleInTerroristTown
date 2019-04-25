#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#undef REQUIRE_PLUGIN
#include <AdvancedParachute>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Parachute"
#define SHORT_NAME "parachute"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;

bool g_bParachute[MAXPLAYERS + 1] =  { false, ... };

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();
    
    TTT_StartConfig("parachute");
    CreateConVar("ttt2_parachute_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("parachute_name", "Parachute", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("parachute_price", "3000", "The amount of credits parachutes costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("parachute_sort_prio", "0", "The sorting priority of the parachutes in the shop menu.");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnAllPluginsLoaded()
{
    char sFile[] = "AdvancedParachute.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
    {
        TTT_RemoveCustomItem(SHORT_NAME);
        SetFailState("You must have this plugin as base plugin for this item: https://forums.alliedmods.net/showthread.php?p=2534158");
        return;
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, SHOP_ITEM_4ALL, g_cPrio.IntValue);
}

public void OnClientDisconnect(int client)
{
    ResetTemplate(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME, false))
        {
            if (g_bParachute[client])
            {
                return Plugin_Stop;
            }
            
            g_bParachute[client] = true;
        }
    }
    return Plugin_Continue;
}

public Action OnParachuteOpen(int client)
{
    if (g_bParachute[client])
    {
        return Plugin_Continue;
    }
    
    return Plugin_Handled;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetTemplate(client);
    }
}

void ResetTemplate(int client)
{
    g_bParachute[client] = false;
}
