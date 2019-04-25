#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <camerasanddrones>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Cameras and Drones"

#define CAMERA_SHORT_NAME "camera"
#define DRONE_SHORT_NAME "drone"

ConVar g_cCLongName = null;
ConVar g_cCPrice = null;
ConVar g_cCPrio = null;
ConVar g_cDLongName = null;
ConVar g_cDPrice = null;
ConVar g_cDPrio = null;

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

    TTT_StartConfig("dronesandcameras");
    CreateConVar("ttt2_drones_and_cameras_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cCLongName = AutoExecConfig_CreateConVar("cad_camera_name", "Camera", "The name of this in Shop");
    g_cCPrice = AutoExecConfig_CreateConVar("cad_camera_price", "9000", "The amount of credits a camera costs as detective. 0 to disable.");
    g_cCPrio = AutoExecConfig_CreateConVar("cad_camera_sort_prio", "0", "The sorting priority of the camera in the shop menu.");
    g_cDLongName = AutoExecConfig_CreateConVar("cad_drone_name", "Drone", "The name of this in Shop");
    g_cDPrice = AutoExecConfig_CreateConVar("cad_drone_price", "9000", "The amount of credits a drone costs as detective. 0 to disable.");
    g_cDPrio = AutoExecConfig_CreateConVar("cad_drone_sort_prio", "0", "The sorting priority of the drone in the shop menu.");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnAllPluginsLoaded()
{
    char sFile[] = "cameras-and-drones.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
    {
        TTT_RemoveCustomItem(CAMERA_SHORT_NAME);
        TTT_RemoveCustomItem(DRONE_SHORT_NAME);
        SetFailState("You must have this plugin as base plugin for this items: https://forums.alliedmods.net/showthread.php?p=2537127");
        return;
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cCLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterCustomItem(CAMERA_SHORT_NAME, sBuffer, g_cCPrice.IntValue, TTT_TEAM_DETECTIVE, g_cCPrio.IntValue);
    
    g_cDLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterCustomItem(DRONE_SHORT_NAME, sBuffer, g_cDPrice.IntValue, TTT_TEAM_TRAITOR, g_cDPrio.IntValue);
}

public void OnClientDisconnect(int client)
{
    ResetCAD(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, CAMERA_SHORT_NAME, false) || StrEqual(itemshort, DRONE_SHORT_NAME, false))
        {
            int role = TTT_GetClientRole(client);

            if (role == TTT_TEAM_DETECTIVE)
            {
                BuyPlayerGear(client);
                OverridePlayerGear(client, 1); // I'll override the gear, because detectives aren't always ct
            }
            else if (role == TTT_TEAM_TRAITOR)
            {
                BuyPlayerGear(client);
                OverridePlayerGear(client, 2);
            }
            else
            {
                return Plugin_Stop;
            }
            
            TTT_RemoveWeaponByClassname(client, "weapon_tagrenade", CS_SLOT_GRENADE);
    
            GivePlayerItem(client, "weapon_tagrenade");
        }
    }
    return Plugin_Continue;
}


public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetCAD(client);
    }
}

void ResetCAD(int client)
{
    OverridePlayerGear(client, -1);
}
