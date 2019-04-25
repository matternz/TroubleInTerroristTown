#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt>
#include <ttt_glow>
#include <multicolors>

#define SHORT_NAME_T "wallhack_t"
#define SHORT_NAME_D "wallhack_d"
#define LONG_NAME "Wallhack"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: " ... LONG_NAME

ConVar g_cTraitorPrice = null;
ConVar g_cDetectivePrice = null;
ConVar g_cTraitor_Prio = null;
ConVar g_cDetective_Prio = null;
ConVar g_cTraitorCooldown = null;
ConVar g_cDetectiveCooldown = null;
ConVar g_cTraitorActive = null;
ConVar g_cDetectiveActive = null;
ConVar g_cLongName = null;
ConVar g_cColorsT = null;
ConVar g_cColorsD = null;
ConVar g_cDefaultRed = null;
ConVar g_cDefaultGreen = null;
ConVar g_cDefaultBlue = null;
ConVar g_cDefaultAlpha = null;

bool g_bOwnWH[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasWH[MAXPLAYERS + 1] =  { false, ... };

Handle g_hTimer[MAXPLAYERS + 1] =  { null, ... };

bool g_bGlow = false;

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

    TTT_StartConfig("wallhack");
    CreateConVar("ttt2_wallhack_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("wh_name", "Wallhack", "The name of the Wallhack in the Shop");
    g_cTraitorPrice = AutoExecConfig_CreateConVar("wh_traitor_price", "9000", "The amount of credits the Traitor-Wallhack costs. 0 to disable.");
    g_cDetectivePrice = AutoExecConfig_CreateConVar("wh_detective_price", "0", "The amount of credits the Dective-Wallhack costs. 0 to disable.");
    g_cTraitorCooldown = AutoExecConfig_CreateConVar("wh_traitor_cooldown", "15.0", "Time of the cooldown for Traitor-Wallhack (time in seconds)");
    g_cDetectiveCooldown = AutoExecConfig_CreateConVar("wh_detective_cooldown", "15.0", "Time of the cooldown for Dective-Wallhack (time in seconds)");
    g_cTraitorActive = AutoExecConfig_CreateConVar("wh_traitor_active", "3.0", "Active time for Traitor-Wallhack (time in seconds)");
    g_cDetectiveActive = AutoExecConfig_CreateConVar("wh_detective_active", "3.0", "Active time for Dective-Wallhack (time in seconds)");
    g_cTraitor_Prio = AutoExecConfig_CreateConVar("wh_traitor_sort_prio", "0", "The sorting priority of the Traitor - Wallhack in the shop menu.");
    g_cDetective_Prio = AutoExecConfig_CreateConVar("wh_detective_sort_prio", "0", "The sorting priority of the Detective - Wallhack in the shop menu.");
    g_cColorsT = AutoExecConfig_CreateConVar("wh_show_roles_traitor", "1", "Show glows as role colors for traitors?", _, true, 0.0, true, 1.0);
    g_cColorsD = AutoExecConfig_CreateConVar("wh_show_roles_detective", "0", "Show glows as role colors for detectives?", _, true, 0.0, true, 1.0);
    g_cDefaultRed = AutoExecConfig_CreateConVar("wh_default_color_red", "255", "Red color of default glow");
    g_cDefaultGreen = AutoExecConfig_CreateConVar("wh_default_color_green", "255", "Green color of default glow");
    g_cDefaultBlue = AutoExecConfig_CreateConVar("wh_default_color_blue", "255", "Blue color of default glow");
    g_cDefaultAlpha = AutoExecConfig_CreateConVar("wh_default_color_alpha", "255", "Alpha of default glow");
    TTT_EndConfig();
    
    HookEvent("player_spawn", Event_PlayerReset);
    HookEvent("player_death", Event_PlayerReset);
    HookEvent("round_end", Event_RoundReset);

    g_bGlow = LibraryExists("ttt_glow");
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "ttt_glow"))
    {
        g_bGlow = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "ttt_glow"))
    {
        g_bGlow = false;
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    if (g_bGlow)
    {
        char sBuffer[MAX_ITEM_LENGTH];
        g_cLongName.GetString(sBuffer, sizeof(sBuffer));
        TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cTraitorPrice.IntValue, TTT_TEAM_TRAITOR, g_cTraitor_Prio.IntValue);
        TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cDetectivePrice.IntValue, TTT_TEAM_DETECTIVE, g_cDetective_Prio.IntValue);
    }
    else
    {
        if (!LibraryExists("ttt_glow"))
        {
            SetFailState("TTT-Glow not loaded!");
        }
        else
        {
            g_bGlow = true;
        }
    }
}

public Action Event_PlayerReset(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (TTT_IsClientValid(client))
    {
        g_bHasWH[client] = false;
        g_bOwnWH[client] = false;
    }
}

public Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
    LoopValidClients(client)
    {
        g_bHasWH[client] = false;
        g_bOwnWH[client] = false;
    }
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME_T, false) || StrEqual(itemshort, SHORT_NAME_D, false))
        {
            if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR && TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE)
            {
                return Plugin_Stop;
            }

            g_bHasWH[client] = true;
            g_bOwnWH[client] = true;

            if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
            {
                g_hTimer[client] = CreateTimer(g_cTraitorActive.FloatValue, Timer_WHActive, GetClientUserId(client));
            }
            else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
            {
                g_hTimer[client] = CreateTimer(g_cDetectiveActive.FloatValue, Timer_WHActive, GetClientUserId(client));
            }
        }
    }
    return Plugin_Continue;
}

public Action Timer_WHActive(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && g_bOwnWH[client] && g_bHasWH[client])
    {
        g_bHasWH[client] = false;
        g_hTimer[client] = null;

        if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
        {
            g_hTimer[client] = CreateTimer(g_cTraitorCooldown.FloatValue, Timer_WHCooldown, GetClientUserId(client));
        }
        else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
        {
            g_hTimer[client] = CreateTimer(g_cDetectiveCooldown.FloatValue, Timer_WHCooldown, GetClientUserId(client));
        }
    }

    return Plugin_Stop;
}

public Action Timer_WHCooldown(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && g_bOwnWH[client] && !g_bHasWH[client])
    {
        g_bHasWH[client] = true;
        g_hTimer[client] = null;

        if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
        {
            g_hTimer[client] = CreateTimer(g_cTraitorActive.FloatValue, Timer_WHActive, GetClientUserId(client));
        }
        else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
        {
            g_hTimer[client] = CreateTimer(g_cDetectiveActive.FloatValue, Timer_WHActive, GetClientUserId(client));
        }
    }

    return Plugin_Stop;
}

public Action TTT_OnGlowCheck(int client, int target, bool &seeTarget, bool &overrideColor, int &red, int &green, int &blue, int &alpha)
{
    if (!TTT_IsRoundActive())
    {
        return Plugin_Handled;
    }

    if (g_bHasWH[client] && g_bOwnWH[client])
    {
        int role = TTT_GetClientRole(client);
        
        if (role == TTT_TEAM_TRAITOR)
        {
            if (!g_cColorsT.BoolValue)
            {
                overrideColor = true;
                red = g_cDefaultRed.IntValue;
                green = g_cDefaultGreen.IntValue;
                blue = g_cDefaultBlue.IntValue;
                alpha = g_cDefaultAlpha.IntValue;
            }
        }
        else if (role == TTT_TEAM_DETECTIVE)
        {
            if (!g_cColorsD.BoolValue)
            {
                overrideColor = true;
                red = g_cDefaultRed.IntValue;
                green = g_cDefaultGreen.IntValue;
                blue = g_cDefaultBlue.IntValue;
                alpha = g_cDefaultAlpha.IntValue;
            }
        }
        
        seeTarget = true;
        return Plugin_Changed;
    }
    
    return Plugin_Handled;
}
