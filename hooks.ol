type LeonardoConfig {
	wwwDir:string
}

type DecoratedResponse {
	config:LeonardoConfig
	request {
		path:string
	}
	content?:string
}

type PreResponseFaultType {
	statusCode:int
	response:string
}

type MaybeString: void | string

interface PreResponseHookIface {
RequestResponse: run(DecoratedResponse)(MaybeString) throws PreResponseFault(PreResponseFaultType)
}

interface PostResponseHookIface {
RequestResponse: run(DecoratedResponse)(void)
}
