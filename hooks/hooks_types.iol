type LeonardoConfig:void {
	.wwwDir:string
}

type DecoratedResponse:void {
	.config:LeonardoConfig
	.request:void {
		.path:string
	}
	.content?:string
}

type PreResponseFaultType:void {
	.statusCode:int
	.response:string
}

type MaybeString: void | string

interface PreResponseHookIface {
RequestResponse: run(DecoratedResponse)(MaybeString) throws PreResponseFault(PreResponseFaultType)
}

interface PostResponseHookIface {
RequestResponse: run(DecoratedResponse)(void)
}
