#include <sourcemod>
#include <sdktools>
#include <store>
#include <smjansson>
#include <sdkhooks>


enum Numeros
{
	String:ModelName[STORE_MAX_NAME_LENGTH],
	Float:thesize
}

new g_size[1024][Numeros];
new g_sizeCount;


new Handle:g_sizeNameIndex = INVALID_HANDLE;
new Float:g_clientsize[MAXPLAYERS+1];


public Plugin:myinfo =
{
	name        = "[Store] Player size",
	author      = "Franc1sco steam: franug",
	description = "Player size component for [Store]",
	version     = "1.0.0",
	url         = "http://servers-cfg.foroactivo.com/"
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Post);

	Store_RegisterItemType("playersize", OnEquip, LoadItem);

}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client) || GetClientTeam(client) <= 1 || IsFakeClient(client))
		return Plugin_Continue;
	

	CreateTimer(1.0, GiveItem, GetClientSerial(client));

	return Plugin_Continue;
}

public Action:GiveItem(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	if (client == 0)
		return Plugin_Handled;

	if (!IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Handled;

	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "playersize", Store_GetClientLoadout(client), OnGetPlayerItem, GetClientSerial(client));
	return Plugin_Handled;
}



public OnClientPostAdminCheck(client)
{
	g_clientsize[client] = 1.0;	
}


public OnGetPlayerItem(ids[], count, any:serial) 
{
	new client = GetClientFromSerial(serial);
	if (client == 0)
		return;
		
	g_clientsize[client] = 1.0;

	
	for (new index = 0; index < count; index++)
	{
		decl String:name[STORE_MAX_NAME_LENGTH];
		Store_GetItemName(ids[index], name, sizeof(name));
		
		new obtenido = -1;
		if (!GetTrieValue(g_sizeNameIndex, name, obtenido))
		{
			continue;
		}
		
		g_clientsize[client] = g_size[obtenido][thesize];

		
			
		break;
	}
	SetEntPropFloat(client, Prop_Send, "m_flModelScale", g_clientsize[client]);
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("playersize", OnEquip, LoadItem);
	}	
}

public Store_OnReloadItems() 
{
	if (g_sizeNameIndex != INVALID_HANDLE)
		CloseHandle(g_sizeNameIndex);
		
	g_sizeNameIndex = CreateTrie();
	g_sizeCount = 0;
}

public LoadItem(const String:itemName[], const String:attrs[])
{
	strcopy(g_size[g_sizeCount][ModelName], STORE_MAX_NAME_LENGTH, itemName);
		
	SetTrieValue(g_sizeNameIndex, g_size[g_sizeCount][ModelName], g_sizeCount);
	
	new Handle:json = json_load(attrs);



	g_size[g_sizeCount][thesize] = json_object_get_float(json, "size"); 
	if (g_size[g_sizeCount][thesize] == 0.0)
		g_size[g_sizeCount][thesize] = 1.0;

	CloseHandle(json);

	
	g_sizeCount++;
}

public Store_ItemUseAction:OnEquip(client, itemId, bool:equipped)
{
	if (!IsClientInGame(client))
	{
		return Store_DoNothing;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "Must be alive to use");
		return Store_DoNothing;
	}
	
	decl String:name[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(itemId, name, sizeof(name));
	
	decl String:loadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
	Store_GetItemLoadoutSlot(itemId, loadoutSlot, sizeof(loadoutSlot));
	
	if (equipped)
	{
		g_clientsize[client] = 1.0;
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", g_clientsize[client]);

		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Unequipped item", displayName);

		return Store_UnequipItem;
	}
	else
	{		
		new obtenido = -1;
		if (!GetTrieValue(g_sizeNameIndex, name, obtenido))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			return Store_DoNothing;
		}
		
		g_clientsize[client] = g_size[obtenido][thesize];
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", g_clientsize[client]);

		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item", displayName);

		return Store_EquipItem;
	}
}


/* Damage code */

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(g_clientsize[victim] != 1.0)
	{
		damage = ((damage / g_clientsize[victim]) / g_clientsize[victim]);
		if(damage < 1.0) damage = 1.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}