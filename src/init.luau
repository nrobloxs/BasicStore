local StoreClient = require(script.StoreClient)
local StoreServer = require(script.StoreServer)

export type Server = StoreServer.StoreServer
export type Client = StoreClient.StoreClient

return {
	Server = StoreServer,
	Client = StoreClient,
}
