export type DataFormat = {
	[string]: any,
}

export type SessionLock = {
	Timestamp: number,
	JobId: string,
}

export type StoredRecord = {
	Data: DataFormat,
	SessionLock: SessionLock?,
}

return {}
