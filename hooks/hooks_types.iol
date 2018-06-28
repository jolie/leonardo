type LeonardoConfig:void {
	.wwwDirectory:string
}

type DecoratedResponse:void {
	.config:LeonardoConfig
	.request:void {
		.path:string
		.query:string | void
	}
	.content:string
}

type PreResponseFaultType:void {
	.statusCode:int
	.response:string
}

interface PreResponseHookIface {
RequestResponse: run(DecoratedResponse)(string) throws PreResponseFault(PreResponseFaultType)
}

interface PostResponseHookIface {
RequestResponse: run(DecoratedResponse)(void)
}
